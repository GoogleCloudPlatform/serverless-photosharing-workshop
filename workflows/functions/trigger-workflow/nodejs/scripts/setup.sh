#!/bin/bash

set -v

# Source folder name for the lab
export SERVICE_SRC=trigger-workflow
export SERVICE_NAME=${SERVICE_SRC}
export REGION=europe-west1
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project)
export BUCKET_NAME=uploaded-pictures-${GOOGLE_CLOUD_PROJECT}
export WORKFLOW_REGION=europe-west4
export WORKFLOW_NAME=picadaily-workflows

# Enable APIs
gcloud services enable cloudfunctions.googleapis.com

## Node.js
gcloud functions deploy ${SERVICE_NAME} \
  --region=${REGION} \
  --source=.. \
  --runtime nodejs10 \
  --entry-point=trigger_workflow \
  --trigger-resource=${BUCKET_NAME} \
  --trigger-event=google.storage.object.finalize \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_CLOUD_PROJECT=${GOOGLE_CLOUD_PROJECT},WORKFLOW_REGION=${WORKFLOW_REGION},WORKFLOW_NAME=${WORKFLOW_NAME}

set +v 