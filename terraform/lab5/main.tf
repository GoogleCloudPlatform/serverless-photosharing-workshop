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
  service_src       = "garbage-collector"
  service_name      = "${local.service_src}-service"
  bucket_images     = "uploaded-pictures-${var.project_id}"
  bucket_thumbnails = "thumbnails-${var.project_id}"
}

# Enable services
resource "google_project_service" "eventarc" {
  service            = "eventarc.googleapis.com"
  disable_on_destroy = false
}

# !!!Don't forget to enable Audit Logs for Cloud Storage as well!!!

# Assume that the container is already built with build.sh

# Deploy to Cloud Run
resource "google_cloud_run_service" "default" {
  name                       = local.service_name
  location                   = var.region
  autogenerate_revision_name = true

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/${local.service_name}"
        env {
          name  = "BUCKET_IMAGES"
          value = local.bucket_images
        }
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

  # Already enabled in Lab 2
  #depends_on = [google_project_service.run]
}

# Make Cloud Run service publicly accessible
resource "google_cloud_run_service_iam_member" "allUsers" {
  service  = google_cloud_run_service.default.name
  location = google_cloud_run_service.default.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Used to retrieve project_number below
data "google_project" "project" {
}

# Give default Compute service account eventarc.eventReceiver role
resource "google_project_iam_binding" "project" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"

  members = [
    "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  ]
}

# Create an AuditLog for Cloud Storage trigger
resource "google_eventarc_trigger" "default" {
  name     = "trigger-auditlog-tf"
  location = var.region
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.audit.log.v1.written"
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "storage.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "storage.objects.delete"
  }
  destination {
    cloud_run_service {
      service = google_cloud_run_service.default.name
      region  = var.region
    }
  }
  service_account = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"

  depends_on = [google_project_service.eventarc]
}
