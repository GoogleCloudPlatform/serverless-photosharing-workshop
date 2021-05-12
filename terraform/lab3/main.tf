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
  service_src     = "collage"
  service_name    = "${local.service_src}-service"
  bucket_name     = "thumbnails-${var.project_id}"
  service_account = "${local.service_src}-scheduler-sa"
}

# Enable services
resource "google_project_service" "cloudscheduler" {
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

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
          name  = "BUCKET_THUMBNAILS"
          value = local.bucket_name
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

# Create a service account
resource "google_service_account" "service_account" {
  account_id   = local.service_account
  display_name = "Collage Scheduler Service Account"
}

# Give the service account permission to invoke the service
data "google_iam_policy" "default" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:${local.service_account}@${var.project_id}.iam.gserviceaccount.com"
    ]
  }
  depends_on = [google_service_account.service_account]
}

resource "google_cloud_run_service_iam_policy" "policy" {
  location    = google_cloud_run_service.default.location
  project     = google_cloud_run_service.default.project
  service     = google_cloud_run_service.default.name
  policy_data = data.google_iam_policy.default.policy_data
  depends_on  = [google_cloud_run_service.default]
}

# Create a Cloud Scheduler job to execute every 1 minute
resource "google_cloud_scheduler_job" "job" {
  name             = "${local.service_name}-job"
  schedule         = "* * * * *"

  http_target {
    http_method = "GET"
    uri         = google_cloud_run_service.default.status[0].url
    oidc_token {
      service_account_email = "${local.service_account}@${var.project_id}.iam.gserviceaccount.com"
      audience = google_cloud_run_service.default.status[0].url
    }
  }

  depends_on = [google_cloud_run_service.default, google_service_account.service_account]
}