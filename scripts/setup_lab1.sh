#!/bin/bash

set -e
set -v

# Enable APIs
gcloud services enable vision.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable appengine.googleapis.com
gcloud services enable firestore.googleapis.com

# Create a public EU multi-region bucket with uniform access
export BUCKET_NAME=uploaded-pictures-${GOOGLE_CLOUD_PROJECT}
gsutil mb -l EU gs://${BUCKET_NAME}
gsutil uniformbucketlevelaccess set on gs://${BUCKET_NAME}
gsutil iam ch allUsers:objectViewer gs://${BUCKET_NAME}

# Create an App Engine app (requirement for Firestore) and Firestore in EU
REGION_FIRESTORE=europe-west2
gcloud app create --region=${REGION_FIRESTORE}
gcloud alpha firestore databases create --region=${REGION_FIRESTORE}

# Deploy the Cloud Function
export SERVICE_NAME=picture-uploaded
export REGION=europe-west1

gcloud functions deploy ${SERVICE_NAME} \
  --region=${REGION} \
  --source=../functions/image-analysis/nodejs \
  --runtime nodejs10 \
  --entry-point=vision_analysis \
  --trigger-resource=${BUCKET_NAME} \
  --trigger-event=google.storage.object.finalize \
  --allow-unauthenticated
