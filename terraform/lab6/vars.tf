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

variable "project_id" {
  type = string
}

variable "region" {
  description = "The region that App Engine, Firestore, Cloud Functions are deployed to."
  type        = string
  default     = "europe-west2"
}

variable "bucket_location" {
  description = "The multi-region that GCS buckets are created in. Possible values: EU, US, ASIA"
  type        = string
  default     = "EU"
}

variable "workflow_region" {
  description = "The region that Workflows deployed"
  type        = string
  default     = "europe-west4"
}