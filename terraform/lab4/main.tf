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
  service_src = "frontend"
}

resource "google_app_engine_standard_app_version" "default" {
  service = "default"
  version_id = "v1"
  runtime = "nodejs10"

  deployment {
    zip {
      source_url = "https://storage.googleapis.com/${google_storage_bucket.source.name}/${google_storage_bucket_object.default.name}"
    }
  }

  env_variables = {
    BUCKET_PICTURES   = "uploaded-pictures-${var.project_id}"
    BUCKET_THUMBNAILS = "thumbnails-${var.project_id}"
  }
}

# Zip the source code
data "archive_file" "default" {
  type        = "zip"
  source_dir  = "${path.module}/../../${local.service_src}/"
  output_path = "tmp/${local.service_src}.zip"
  excludes    = ["node_modules", "package-lock.json"]
}

# Create a storage bucket for the source
resource "google_storage_bucket" "source" {
  name = "source-${local.service_src}-${var.project_id}"
}

# Upload the zip to the bucket. The archive in Cloud Stoage uses the md5 of the zip file.
# This ensures the function is redeployed only when the source is changed.
resource "google_storage_bucket_object" "default" {
  name   = "${local.service_src}_${data.archive_file.default.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.default.output_path

  depends_on = [data.archive_file.default, google_storage_bucket.source]
}