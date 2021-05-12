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
  service_src     = "thumbnails"
  service_name    = "${local.service_src}-service"
  bucket_name     = "${local.service_src}-${var.project_id}"
  bucket_pictures = "uploaded-pictures-${var.project_id}"
  topic_name      = "gcs-events"
  service_account = "${local.topic_name}-sa"
}

# Enable services
resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# Create a multi-region bucket with uniform bucket level access
resource "google_storage_bucket" "bucket" {
  name          = local.bucket_name
  location      = var.bucket_location
  force_destroy = true

  uniform_bucket_level_access = true
}

# Make the bucket public
resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.bucket.name
  role = "roles/storage.objectViewer"
  member = "allUsers"
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

  depends_on = [google_project_service.run]
}

# Create a Pub/Sub topic as the communication pipeline
resource "google_pubsub_topic" "default" {
  name = local.topic_name
}

# Create Pub/Sub notifications when files are stored in the bucket
resource "google_storage_notification" "default" {
  bucket         = local.bucket_pictures
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.default.id
  depends_on     = [google_pubsub_topic.default]
}

# Enable notifications by giving the correct IAM permission to the unique service account.
data "google_storage_project_service_account" "gcs_account" {
}

resource "google_pubsub_topic_iam_binding" "binding" {
  topic   = google_pubsub_topic.default.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

# Create a service account to represent the Pub/Sub subscription identity
resource "google_service_account" "service_account" {
  account_id   = local.service_account
  display_name = "Cloud Run Pub/Sub Invoker"
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

# Finally, create a Pub/Sub subscription with the service account
resource "google_pubsub_subscription" "default" {
  name  = "${local.topic_name}-subscription"
  topic = google_pubsub_topic.default.name

  push_config {
    push_endpoint = google_cloud_run_service.default.status[0].url

    oidc_token {
      service_account_email = "${local.service_account}@${var.project_id}.iam.gserviceaccount.com"
    }
  }

  depends_on = [google_cloud_run_service.default, google_pubsub_topic.default, google_service_account.service_account]
}