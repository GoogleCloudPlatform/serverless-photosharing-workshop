#!/bin/bash

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -v

#####################
# Thumbnail Service #

SERVICE_SRC=../../workflows/services/thumbnails/nodejs
SERVICE_NAME=thumbnails-service

gcloud builds submit \
  ${SERVICE_SRC} \
  --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME}

###################
# Collage Service #

SERVICE_SRC=../../services/collage/nodejs
SERVICE_NAME=collage-service

gcloud builds submit \
  ${SERVICE_SRC} \
  --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME}