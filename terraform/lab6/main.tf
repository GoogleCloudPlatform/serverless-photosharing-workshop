/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  bucket_pictures               = "uploaded-pictures-${var.project_id}"
  bucket_thumbnails             = "thumbnails-${var.project_id}"
  service_src_thumbnails        = "thumbnails"
  service_name_thumbnails       = "${local.service_src_thumbnails}-service"
  service_src_collage           = "collage"
  service_name_collage          = "${local.service_src_collage}-service"
  service_src_vision_data       = "vision-data-transform"
  service_name_vision_data      = local.service_src_vision_data
  workflow_name                 = "picadaily-workflows"
  service_src_trigger           = "trigger-workflow"
  service_name_trigger_finalize = "${local.service_src_trigger}-on-finalize"
  service_name_trigger_delete   = "${local.service_src_trigger}-on-delete"
  service_src_frontend          = "frontend"
}

# List of services to enable
variable "gcp_services" {
  type = list(string)
  default = [
    "appengine.googleapis.com",
    "compute.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "firestore.googleapis.com",
    "run.googleapis.com",
    "vision.googleapis.com",
    "workflows.googleapis.com"
  ]
}

# Enable services
resource "google_project_service" "services" {
  for_each           = toset(var.gcp_services)
  service            = each.value
  disable_on_destroy = false
}

#####################
# Setup GCS buckets #

# Create a multi-region bucket with uniform bucket level access
resource "google_storage_bucket" "uploaded_pictures" {
  name          = local.bucket_pictures
  location      = var.bucket_location
  force_destroy = true

  uniform_bucket_level_access = true
}

# Make the bucket public
resource "google_storage_bucket_iam_member" "uploaded_pictures" {
  bucket = google_storage_bucket.uploaded_pictures.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Create a multi-region bucket with uniform bucket level access
resource "google_storage_bucket" "thumbnails" {
  name          = local.bucket_thumbnails
  location      = var.bucket_location
  force_destroy = true

  uniform_bucket_level_access = true
}

# Make the bucket public
resource "google_storage_bucket_iam_member" "thumbnails" {
  bucket = google_storage_bucket.thumbnails.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

###################
# Setup Firestore #

# Create an App Engine app (requirement for Firestore) and Firestore
resource "google_app_engine_application" "default" {
  project       = var.project_id
  location_id   = var.region
  database_type = "CLOUD_FIRESTORE"

  depends_on = [
    google_project_service.services
  ]
}

# Create Firestore index
resource "google_firestore_index" "default" {

  collection = "pictures"

  fields {
    field_path = "thumbnail"
    order      = "DESCENDING"
  }

  fields {
    field_path = "created"
    order      = "DESCENDING"
  }

  depends_on = [
    google_project_service.services,
    #google_app_engine_application.default
  ]
}

#####################
# Thumbnail Service #

# Assume that the container is already built with build.sh

# Deploy to Cloud Run
resource "google_cloud_run_service" "thumbnails" {
  name                       = local.service_name_thumbnails
  location                   = var.region
  autogenerate_revision_name = true

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/${local.service_name_thumbnails}"
        env {
          name  = "BUCKET_THUMBNAILS"
          value = local.bucket_thumbnails
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.services
  ]
}

###################
# Collage Service #

# Assume that the container is already built with build.sh

# Deploy to Cloud Run
resource "google_cloud_run_service" "collage" {
  name                       = local.service_name_collage
  location                   = var.region
  autogenerate_revision_name = true

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/${local.service_name_collage}"
        env {
          name  = "BUCKET_THUMBNAILS"
          value = local.bucket_thumbnails
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.services
  ]
}

#######################################
# Vision Data Transformation Function #

# Zip the source code
data "archive_file" "vision_data" {
  type        = "zip"
  source_dir  = "${path.module}/../../workflows/functions/${local.service_src_vision_data}/nodejs/"
  output_path = "tmp/${local.service_src_vision_data}.zip"
  excludes    = ["node_modules", "package-lock.json"]
}

# Create a storage bucket for the source
resource "google_storage_bucket" "vision_data" {
  name = "source-${local.service_src_vision_data}-${var.project_id}"
}

# Upload the zip to the bucket. The archive in Cloud Stoage uses the md5 of the zip file.
# This ensures the function is redeployed only when the source is changed.
resource "google_storage_bucket_object" "vision_data" {
  name   = "${local.service_src_vision_data}_${data.archive_file.vision_data.output_md5}.zip"
  bucket = google_storage_bucket.vision_data.name
  source = data.archive_file.vision_data.output_path

  depends_on = [
    data.archive_file.vision_data,
    google_storage_bucket.vision_data
  ]
}

# Deploy the Cloud Function
resource "google_cloudfunctions_function" "vision_data" {
  name                  = local.service_name_vision_data
  region                = var.region
  source_archive_bucket = google_storage_bucket.vision_data.name
  source_archive_object = google_storage_bucket_object.vision_data.name
  runtime               = "nodejs10"
  trigger_http          = true
  entry_point           = "vision_data_transform"

  depends_on = [
    google_project_service.services,
    google_storage_bucket_object.vision_data
  ]
}

# Make the function public
resource "google_cloudfunctions_function_iam_member" "vision_data" {
  cloud_function = google_cloudfunctions_function.vision_data.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

#######################
# Workflow deployment #

resource "google_workflows_workflow" "picadaily" {
  name            = local.workflow_name
  region          = var.workflow_region
  source_contents = templatefile("${path.module}/../../workflows/workflows_tf.yaml", {})

  depends_on = [
    google_project_service.services
  ]
}

#################################
# Workflow triggering Functions #

# Trigger workflow for FINALIZE event

# Zip the source code
data "archive_file" "trigger_workflow" {
  type        = "zip"
  source_dir  = "${path.module}/../../workflows/functions/${local.service_src_trigger}/nodejs/"
  output_path = "tmp/${local.service_src_trigger}.zip"
  excludes    = ["node_modules", "package-lock.json"]
}

# Create a storage bucket for the source
resource "google_storage_bucket" "trigger_workflow" {
  name = "source-${local.service_src_trigger}-${var.project_id}"
}

# Upload the zip to the bucket. The archive in Cloud Stoage uses the md5 of the zip file.
# This ensures the function is redeployed only when the source is changed.
resource "google_storage_bucket_object" "trigger_workflow" {
  name   = "${local.service_src_trigger}_${data.archive_file.trigger_workflow.output_md5}.zip"
  bucket = google_storage_bucket.trigger_workflow.name
  source = data.archive_file.trigger_workflow.output_path

  depends_on = [
    data.archive_file.trigger_workflow,
    google_storage_bucket.trigger_workflow
  ]
}

# Deploy the Cloud Function
resource "google_cloudfunctions_function" "trigger_workflow_finalize" {
  name                  = local.service_name_trigger_finalize
  region                = var.region
  source_archive_bucket = google_storage_bucket.trigger_workflow.name
  source_archive_object = google_storage_bucket_object.trigger_workflow.name
  runtime               = "nodejs10"
  entry_point           = "trigger_workflow"
  event_trigger {
    resource   = local.bucket_pictures
    event_type = "google.storage.object.finalize"
  }

  environment_variables = {
    GOOGLE_CLOUD_PROJECT      = var.project_id
    WORKFLOW_REGION           = var.workflow_region
    WORKFLOW_NAME             = local.workflow_name
    THUMBNAILS_URL            = google_cloud_run_service.thumbnails.status[0].url
    COLLAGE_URL               = google_cloud_run_service.collage.status[0].url
    VISION_DATA_TRANSFORM_URL = google_cloudfunctions_function.vision_data.https_trigger_url
  }

  depends_on = [google_project_service.services,
    google_storage_bucket_object.trigger_workflow,
    google_workflows_workflow.picadaily,
    google_cloud_run_service.thumbnails,
    google_cloud_run_service.collage,
    google_cloudfunctions_function.vision_data
  ]
}

# Make the function public
resource "google_cloudfunctions_function_iam_member" "trigger_workflow_finalize" {
  cloud_function = google_cloudfunctions_function.vision_data.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

# Trigger workflow for DELETION event

# Deploy the Cloud Function
resource "google_cloudfunctions_function" "trigger_workflow_delete" {
  name                  = local.service_name_trigger_delete
  region                = var.region
  source_archive_bucket = google_storage_bucket.trigger_workflow.name
  source_archive_object = google_storage_bucket_object.trigger_workflow.name
  runtime               = "nodejs10"
  entry_point           = "trigger_workflow"
  event_trigger {
    resource   = local.bucket_pictures
    event_type = "google.storage.object.delete"
  }

  environment_variables = {
    GOOGLE_CLOUD_PROJECT      = var.project_id
    WORKFLOW_REGION           = var.workflow_region
    WORKFLOW_NAME             = local.workflow_name
    THUMBNAILS_URL            = google_cloud_run_service.thumbnails.status[0].url
    COLLAGE_URL               = google_cloud_run_service.collage.status[0].url
    VISION_DATA_TRANSFORM_URL = google_cloudfunctions_function.vision_data.https_trigger_url
  }

  depends_on = [google_project_service.services,
    google_storage_bucket_object.trigger_workflow,
    google_workflows_workflow.picadaily,
    google_cloud_run_service.thumbnails,
    google_cloud_run_service.collage,
    google_cloudfunctions_function.vision_data
  ]
}

# Make the function public
resource "google_cloudfunctions_function_iam_member" "trigger_workflow_delete" {
  cloud_function = google_cloudfunctions_function.vision_data.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

###########################
# App Engine web frontend #

# Zip the source code
data "archive_file" "frontend" {
  type        = "zip"
  source_dir  = "${path.module}/../../${local.service_src_frontend}/"
  output_path = "tmp/${local.service_src_frontend}.zip"
  excludes    = ["node_modules", "package-lock.json"]
}

# Create a storage bucket for the source
resource "google_storage_bucket" "frontend" {
  name = "source-${local.service_src_frontend}-${var.project_id}"
}

# Upload the zip to the bucket. The archive in Cloud Stoage uses the md5 of the zip file.
# This ensures the function is redeployed only when the source is changed.
resource "google_storage_bucket_object" "frontend" {
  name   = "${local.service_src_frontend}_${data.archive_file.frontend.output_md5}.zip"
  bucket = google_storage_bucket.frontend.name
  source = data.archive_file.frontend.output_path

  depends_on = [
    data.archive_file.frontend,
    google_storage_bucket.frontend
  ]
}

resource "google_app_engine_standard_app_version" "default" {
  service    = "default"
  version_id = "v1"
  runtime    = "nodejs10"

  deployment {
    zip {
      source_url = "https://storage.googleapis.com/${google_storage_bucket.frontend.name}/${google_storage_bucket_object.frontend.name}"
    }
  }

  env_variables = {
    BUCKET_PICTURES   = "uploaded-pictures-${var.project_id}"
    BUCKET_THUMBNAILS = "thumbnails-${var.project_id}"
  }

  depends_on = [
    google_project_service.services,
    google_storage_bucket_object.frontend
  ]
}