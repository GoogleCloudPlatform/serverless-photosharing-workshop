#!/bin/bash

set -v

# Enable services
gcloud services enable appengine.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable vision.googleapis.com

# Create a public multi-region bucket with uniform level access
export BUCKET_NAME=uploaded-pictures-${GOOGLE_CLOUD_PROJECT}
export BUCKET_LOCATION=EU # EU, USA, ASIA

gsutil mb -l ${BUCKET_LOCATION} gs://${BUCKET_NAME}
gsutil uniformbucketlevelaccess set on gs://${BUCKET_NAME}
gsutil iam ch allUsers:objectViewer gs://${BUCKET_NAME}

# Create an App Engine app (requirement for Firestore) and Firestore
export REGION=europe-west2
gcloud app create --region=${REGION}
gcloud firestore databases create --region=${REGION}

# Create Firestore index
gcloud firestore indexes composite create --collection-group=pictures \
  --field-config field-path=thumbnail,order=descending \
  --field-config field-path=created,order=descending

# Deploy the Cloud Function
export SERVICE_NAME=picture-uploaded

## Node.js
gcloud functions deploy ${SERVICE_NAME} \
  --region=${REGION} \
  --source=../functions/image-analysis/nodejs \
  --runtime nodejs10 \
  --entry-point=vision_analysis \
  --trigger-resource=${BUCKET_NAME} \
  --trigger-event=google.storage.object.finalize \
  --allow-unauthenticated

## C#
# gcloud functions deploy ${SERVICE_NAME} \
#   --region=${REGION} \
#   --source=../functions/image-analysis/csharp \
#   --runtime dotnet3 \
#   --entry-point=ImageAnalysis.Function \
#   --trigger-resource=${BUCKET_NAME} \
#   --trigger-event=google.storage.object.finalize \
#   --allow-unauthenticated \
#   --set-env-vars PROJECT_ID=${GOOGLE_CLOUD_PROJECT}

## Java
# gcloud functions deploy ${SERVICE_NAME} \
#  --region=${REGION} \
#  --source=../functions/image-analysis/java \
#  --runtime java11 \
#  --entry-point=fn.ImageAnalysis \
#  --trigger-resource=${BUCKET_NAME} \
#  --trigger-event=google.storage.object.finalize \
#  --allow-unauthenticated