#!/bin/bash

set -v

# Source folder name for the lab
export SERVICE_SRC=garbage-collector

# Enable APIs
gcloud services enable eventarc.googleapis.com

# Don't forget to enable Audit Logs for Cloud Storage as well!

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
export REGION=europe-west1
gcloud config set run/region ${REGION}
gcloud config set run/platform managed
export BUCKET_IMAGES=uploaded-pictures-${GOOGLE_CLOUD_PROJECT}
export BUCKET_THUMBNAILS=thumbnails-${GOOGLE_CLOUD_PROJECT}

## Node.js
gcloud run deploy ${SERVICE_NAME} \
    --image gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME} \
    --allow-unauthenticated \
    --update-env-vars BUCKET_IMAGES=${BUCKET_IMAGES},BUCKET_THUMBNAILS=${BUCKET_THUMBNAILS}

## C#
# gcloud run deploy ${SERVICE_NAME} \
#     --image gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME} \
#     --allow-unauthenticated \
#     --update-env-vars BUCKET_IMAGES=${BUCKET_IMAGES},BUCKET_THUMBNAILS=${BUCKET_THUMBNAILS},PROJECT_ID=${GOOGLE_CLOUD_PROJECT}

# Set up Eventarc

# Give default Compute service account eventarc.eventReceiver role
export PROJECT_NUMBER="$(gcloud projects list --filter=$(gcloud config get-value project) --format='value(PROJECT_NUMBER)')"

gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
    --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
    --role='roles/eventarc.eventReceiver'

# Set eventarc/location
gcloud config set eventarc/location ${REGION}

# Create trigger
gcloud eventarc triggers create trigger-${SERVICE_NAME} \
  --destination-run-service=${SERVICE_NAME} \
  --destination-run-region=${REGION} \
  --event-filters="type=google.cloud.audit.log.v1.written" \
  --event-filters="serviceName=storage.googleapis.com" \
  --event-filters="methodName=storage.objects.delete" \
  --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com



