#!/bin/bash

set -v

PROJECT=FIXME

NAMESPACE=config-control

export SERVICE_SRC=thumbnails

# Enable services
kubectl apply -f services.yaml -n $NAMESPACE

# Create a public multi-region bucket with uniform level access
export BUCKET_NAME=uploaded-pictures-${PROJECT}
export BUCKET_LOCATION=EU # EU, USA, ASIA
sed -i "s/BUCKET_NAME/$BUCKET_NAME/g;s/BUCKET_LOCATION/$BUCKET_LOCATION/g" storage.yaml
kubectl apply -f storage.yaml -n $NAMESPACE

# Create Cloud Run
# kubectl apply -f run.yaml -n $NAMESPACE
export REGION=europe-west2
gcloud config set run/region ${REGION}
gcloud config set run/platform managed
## Node.js
gcloud run deploy ${SERVICE_NAME} \
    --image gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME} \
    --no-allow-unauthenticated \
    --memory=1Gi \
    --update-env-vars BUCKET_THUMBNAILS=${BUCKET_NAME}