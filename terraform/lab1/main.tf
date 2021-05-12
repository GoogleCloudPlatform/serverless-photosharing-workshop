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
  bucket_name = "uploaded-pictures-${var.project_id}"
  service_name = "picture-uploaded"
}

# List of services to enable
variable "gcp_services" {
  type = list(string)
  default = [
    "appengine.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "firestore.googleapis.com",
    "vision.googleapis.com"
  ]
}

# Enable services
resource "google_project_service" "default" {
  for_each = toset(var.gcp_services)
  service  = each.value
  disable_on_destroy = false
}

# Create a multi-region bucket
resource "google_storage_bucket" "bucket" {
  name          = local.bucket_name
  location      = var.bucket_location
  force_destroy = true

  #uniform_bucket_level_access = true
}

# Make the bucket public
resource "google_storage_bucket_access_control" "public_rule" {
  bucket = google_storage_bucket.bucket.name
  role   = "READER"
  entity = "allUsers"
}

# Create an App Engine app (requirement for Firestore) and Firestore
resource "google_app_engine_application" "default" {
  project       = var.project_id
  location_id   = var.region
  database_type = "CLOUD_FIRESTORE"
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
}

# Zip the source code
data "archive_file" "image_analysis" {
  type        = "zip"
  source_dir  = "${path.module}/../../functions/image-analysis/nodejs/"
  output_path = "tmp/image_analysis.zip"
  excludes    = [ "node_modules", "package-lock.json" ]
}

# Create a storage bucket for Cloud Functions src
resource "google_storage_bucket" "source" {
  name = "source-${var.project_id}"
}

# Upload the zip to the bucket
# The archive in Cloud Stoage uses the md5 of the zip file.
# This ensures the function is redeployed only when the source is changed.
resource "google_storage_bucket_object" "image_analysis" {
  name   = "image_analysis_${data.archive_file.image_analysis.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.image_analysis.output_path

  depends_on = [data.archive_file.image_analysis]
}

# Deploy the Cloud Function

## Node.js
resource "google_cloudfunctions_function" "default" {
  name                  = local.service_name
  region                = var.region
  source_archive_bucket = google_storage_bucket.source.name
  source_archive_object = google_storage_bucket_object.image_analysis.name
  runtime               = "nodejs10"
  entry_point           = "vision_analysis"
  event_trigger {
    resource   = local.bucket_name
    event_type = "google.storage.object.finalize"
  }

}

# Make the function public
resource "google_cloudfunctions_function_iam_member" "invoker" {
  cloud_function = google_cloudfunctions_function.default.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}