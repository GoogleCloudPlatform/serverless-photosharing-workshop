#!/bin/bash

set -v

# Source folder name for the lab
export SERVICE_SRC=thumbnails

# Enable APIs
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com

# Create a public EU multi-region bucket with uniform access
export BUCKET_NAME=${SERVICE_SRC}-${GOOGLE_CLOUD_PROJECT}
gsutil mb -l EU gs://${BUCKET_NAME}
gsutil uniformbucketlevelaccess set on gs://${BUCKET_NAME}
gsutil iam ch allUsers:objectViewer gs://${BUCKET_NAME}

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

# Setup Pub/Sub notification to Cloud Run

# Create a Pub/Sub topic as the communication pipeline
export TOPIC_NAME=gcs-events
gcloud pubsub topics create ${TOPIC_NAME}

# Create Pub/Sub notifications when files are stored in the bucket
export BUCKET_PICTURES=uploaded-pictures-${GOOGLE_CLOUD_PROJECT}
gsutil notification create -t ${TOPIC_NAME} -f json gs://${BUCKET_PICTURES}

# Create a service account to represent the Pub/Sub subscription identity
export SERVICE_ACCOUNT=${TOPIC_NAME}-sa
gcloud iam service-accounts create ${SERVICE_ACCOUNT} \
     --display-name "Cloud Run Pub/Sub Invoker"

# Give the service account permission to invoke the service
gcloud run services add-iam-policy-binding ${SERVICE_NAME} \
   --member=serviceAccount:${SERVICE_ACCOUNT}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com \
   --role=roles/run.invoker

# Enable Pub/Sub to create authentication tokens in our project
export PROJECT_NUMBER="$(gcloud projects list --filter=${GOOGLE_CLOUD_PROJECT} --format='value(PROJECT_NUMBER)')"
gcloud projects add-iam-policy-binding ${GOOGLE_CLOUD_PROJECT} \
     --member=serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com \
     --role=roles/iam.serviceAccountTokenCreator

# Finally, create a Pub/Sub subscription with the service account
export SERVICE_URL="$(gcloud run services list --platform managed --filter=${SERVICE_NAME} --format='value(URL)')"
gcloud pubsub subscriptions create ${TOPIC_NAME}-subscription --topic ${TOPIC_NAME} \
   --push-endpoint=${SERVICE_URL} \
   --push-auth-service-account=${SERVICE_ACCOUNT}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com
