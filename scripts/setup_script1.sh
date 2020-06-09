#!/bin/bash

set -v

# Enable Vision and Cloud Functions APIs
gcloud services enable vision.googleapis.com
gcloud services enable cloudfunctions.googleapis.com

# Create a standard multi-region zone in Europe
export BUCKET_PICTURES=uploaded-pictures-${GOOGLE_CLOUD_PROJECT}
gsutil mb -l EU gs://${BUCKET_PICTURES}

# Ensure uniform bucket level access
gsutil uniformbucketlevelaccess set on gs://${BUCKET_PICTURES}

# Make the bucket public
gsutil iam ch allUsers:objectViewer gs://${BUCKET_PICTURES}

# Create an App Engine app (requirement for Firestore) in Europe
gcloud app create --region=europe-west2

# Create the Firestore database in Europe
gcloud alpha firestore databases create --region=europe-west2

# Deploy the Cloud Function
export SERVICE_NAME=picture-uploaded
export REGION=europe-west1

gcloud functions deploy ${SERVICE_NAME} \
  --region=${REGION} \
  --source=../functions/image-analysis/nodejs \
  --runtime nodejs10 \
  --entry-point=vision_analysis \
  --trigger-resource=${BUCKET_PICTURES} \
  --trigger-event=google.storage.object.finalize \
  --allow-unauthenticated