#!/bin/bash

set -v

# Source folder name for the lab
export SERVICE_SRC=garbage-collector
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project)

# Enable APIs
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com

# Build the container
export SERVICE_NAME=${SERVICE_SRC}-service

## Node.js
gcloud builds submit \
  .. \
  --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME}

# Deploy to Cloud Run
export REGION=europe-west1
gcloud config set run/region ${REGION}
gcloud config set run/platform managed
export BUCKET_THUMBNAILS=thumbnails-${GOOGLE_CLOUD_PROJECT}

## Node.js
gcloud run deploy ${SERVICE_NAME} \
    --image gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME} \
    --no-allow-unauthenticated \
    --update-env-vars BUCKET_THUMBNAILS=${BUCKET_THUMBNAILS}

# Test Local
# curl -v -X POST \
# -H "Authorization: Bearer "$(gcloud auth application-default print-access-token) \
# -H "Content-Type: application/json; charset=utf-8" \
# -d @request.json \
# http://localhost:8080

# Test Cloud Run service
# export SERVICE_URL="$(gcloud run services list --platform managed --filter=${SERVICE_NAME} --format='value(URL)')"
# curl -v -X POST \
# -H "Authorization: Bearer "$(gcloud auth application-default print-access-token) \
# -H "Content-Type: application/json; charset=utf-8" \
# -d @request.json \
# ${SERVICE_URL}