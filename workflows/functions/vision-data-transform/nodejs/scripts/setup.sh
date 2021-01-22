#!/bin/bash

set -v

# Source folder name for the lab
export SERVICE_SRC=vision-data-transform
export SERVICE_NAME=${SERVICE_SRC}
export REGION=europe-west1
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project)

# Enable APIs
gcloud services enable cloudfunctions.googleapis.com

## Node.js
gcloud functions deploy ${SERVICE_NAME} \
  --region=${REGION} \
  --source=.. \
  --runtime nodejs10 \
  --entry-point=vision_data_transform \
  --trigger-http \
  --allow-unauthenticated

set +v