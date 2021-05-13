set -v

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

export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project)

# Enable APIs
gcloud services enable compute.googleapis.com
gcloud services enable appengine.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable vision.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable workflows.googleapis.com

#####################
# Setup GCS buckets #
export BUCKET_PICTURES=uploaded-pictures-${GOOGLE_CLOUD_PROJECT}
export BUCKET_THUMBNAILS=thumbnails-${GOOGLE_CLOUD_PROJECT}

# Create a public EU multi-region bucket with uniform access
gsutil mb -l EU gs://${BUCKET_PICTURES}
gsutil uniformbucketlevelaccess set on gs://${BUCKET_PICTURES}
gsutil iam ch allUsers:objectViewer gs://${BUCKET_PICTURES}

# Create a public EU multi-region bucket with uniform access
gsutil mb -l EU gs://${BUCKET_THUMBNAILS}
gsutil uniformbucketlevelaccess set on gs://${BUCKET_THUMBNAILS}
gsutil iam ch allUsers:objectViewer gs://${BUCKET_THUMBNAILS}

###################
# Setup Firestore #

# Create an App Engine app (requirement for Firestore) and Firestore in EU
export REGION_FIRESTORE=europe-west2

gcloud app create --region=${REGION_FIRESTORE}
gcloud firestore databases create --region=${REGION_FIRESTORE}
gcloud firestore indexes composite create --collection-group=pictures \
  --field-config field-path=thumbnail,order=descending \
  --field-config field-path=created,order=descending

#####################################
# Deployment settings for Cloud Run #
export REGION=europe-west1
gcloud config set run/region ${REGION}
gcloud config set run/platform managed

#####################
# Thumbnail Service #

# Source folder name for the lab
export SERVICE_SRC=thumbnails

# Build the container
export SERVICE_NAME=${SERVICE_SRC}-service

## Node.js
gcloud builds submit \
  ../workflows/services/${SERVICE_SRC}/nodejs \
  --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME}

## Node.js
gcloud run deploy ${SERVICE_NAME} \
    --image gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME} \
    --no-allow-unauthenticated \
    --memory=1Gi \
    --update-env-vars BUCKET_THUMBNAILS=${BUCKET_THUMBNAILS}

export THUMBNAILS_URL=$(gcloud run services describe ${SERVICE_NAME} --format 'value(status.url)')
echo $THUMBNAILS_URL

###################
# Collage Service #

# Source folder name for the lab
export SERVICE_SRC=collage

# Build the container
export SERVICE_NAME=${SERVICE_SRC}-service

## Node.js
gcloud builds submit \
  ../services/${SERVICE_SRC}/nodejs \
  --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME}

## Node.js
gcloud run deploy ${SERVICE_NAME} \
    --image gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME} \
    --no-allow-unauthenticated \
    --memory=1Gi \
    --update-env-vars BUCKET_THUMBNAILS=${BUCKET_THUMBNAILS}

export COLLAGE_URL=$(gcloud run services describe ${SERVICE_NAME} --format 'value(status.url)')
echo $COLLAGE_URL

###########################################
# Deployment settings for Cloud Functions #
gcloud config set functions/region ${REGION}

#######################################
# Vision Data Transformation Function #

# Source folder name for the lab
export SERVICE_SRC=vision-data-transform
export SERVICE_NAME=${SERVICE_SRC}

## Node.js
gcloud functions deploy ${SERVICE_NAME} \
  --source=../workflows/functions/${SERVICE_SRC}/nodejs \
  --runtime nodejs10 \
  --entry-point=vision_data_transform \
  --trigger-http \
  --allow-unauthenticated

export VISION_DATA_TRANSFORM_URL=$(gcloud functions describe vision-data-transform --format 'value(httpsTrigger.url)')
echo $VISION_DATA_TRANSFORM_URL

#######################
# Workflow deployment #

export WORKFLOW_REGION=europe-west4
export WORKFLOW_NAME=picadaily-workflows

gcloud workflows deploy ${WORKFLOW_NAME} --source=../workflows/workflows.yaml --location=${WORKFLOW_REGION}

#################################
# Workflow triggering Functions #

# Source folder name for the lab
export SERVICE_SRC=trigger-workflow

# Trigger workflow for FINALIZE event

export SERVICE_NAME=${SERVICE_SRC}-on-finalize

## Node.js
gcloud functions deploy ${SERVICE_NAME} \
  --source=../workflows/functions/${SERVICE_SRC}/nodejs \
  --runtime nodejs10 \
  --entry-point=trigger_workflow \
  --trigger-resource=${BUCKET_PICTURES} \
  --trigger-event=google.storage.object.finalize \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_CLOUD_PROJECT=${GOOGLE_CLOUD_PROJECT},WORKFLOW_REGION=${WORKFLOW_REGION},WORKFLOW_NAME=${WORKFLOW_NAME},THUMBNAILS_URL=${THUMBNAILS_URL},COLLAGE_URL=${COLLAGE_URL},VISION_DATA_TRANSFORM_URL=${VISION_DATA_TRANSFORM_URL}

# Trigger workflow for DELETION event

export SERVICE_NAME=${SERVICE_SRC}-on-delete

## Node.js
gcloud functions deploy ${SERVICE_NAME} \
  --source=../workflows/functions/${SERVICE_SRC}/nodejs \
  --runtime nodejs10 \
  --entry-point=trigger_workflow \
  --trigger-resource=${BUCKET_PICTURES} \
  --trigger-event=google.storage.object.delete \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_CLOUD_PROJECT=${GOOGLE_CLOUD_PROJECT},WORKFLOW_REGION=${WORKFLOW_REGION},WORKFLOW_NAME=${WORKFLOW_NAME},THUMBNAILS_URL=${THUMBNAILS_URL},COLLAGE_URL=${COLLAGE_URL},VISION_DATA_TRANSFORM_URL=${VISION_DATA_TRANSFORM_URL}

###########################
# App Engine web frontend #

# Source folder name for the lab
export SERVICE_SRC=frontend

# Add project id to the env variables in app.yaml
sed -i -e "s/GOOGLE_CLOUD_PROJECT/${GOOGLE_CLOUD_PROJECT}/" ../${SERVICE_SRC}/app.yaml

# Set the region
gcloud config set compute/region europe-west1

# Deploy to App Engine
gcloud app deploy ../${SERVICE_SRC}/app.yaml -q

set +v
