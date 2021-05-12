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

# Source folder name for the lab
export SERVICE_SRC=collage

# Enable APIs
gcloud services enable cloudscheduler.googleapis.com

# Build the container
export SERVICE_NAME=${SERVICE_SRC}-service

## Node.js
gcloud builds submit \
  ../services/${SERVICE_SRC}/nodejs \
  --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME}

## C#
# gcloud builds submit \
#   ../services/${SERVICE_SRC}/csharp \
#   --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME}

# Deploy to Cloud Run
export REGION=europe-west2
gcloud config set run/region ${REGION}
gcloud config set run/platform managed
export BUCKET_NAME=thumbnails-${GOOGLE_CLOUD_PROJECT}

## Node.js
gcloud run deploy ${SERVICE_NAME} \
    --image gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME} \
    --no-allow-unauthenticated \
    --memory=1Gi \
    --update-env-vars BUCKET_THUMBNAILS=${BUCKET_NAME}

## C#
# gcloud run deploy ${SERVICE_NAME} \
#     --image gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME} \
#     --no-allow-unauthenticated \
#     --memory=1Gi \
#     --update-env-vars BUCKET_THUMBNAILS=${BUCKET_NAME},PROJECT_ID=${GOOGLE_CLOUD_PROJECT}

# Set up Cloud Scheduler

# Create a service account
export SERVICE_ACCOUNT=${SERVICE_SRC}-scheduler-sa
gcloud iam service-accounts create ${SERVICE_ACCOUNT} \
   --display-name "Collage Scheduler Service Account"

# Give service account permission to invoke the Cloud Run service
gcloud run services add-iam-policy-binding ${SERVICE_NAME} \
   --member=serviceAccount:${SERVICE_ACCOUNT}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com \
   --role=roles/run.invoker

# Create a Cloud Scheduler job to execute every 1 minute
export SERVICE_URL="$(gcloud run services list --platform managed --filter=${SERVICE_NAME} --format='value(URL)')"
gcloud scheduler jobs create http ${SERVICE_NAME}-job --schedule "* * * * *" \
   --http-method=GET \
   --uri=${SERVICE_URL} \
   --oidc-service-account-email=${SERVICE_ACCOUNT}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com \
   --oidc-token-audience=${SERVICE_URL}



