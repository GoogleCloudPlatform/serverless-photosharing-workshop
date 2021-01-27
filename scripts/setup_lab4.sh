#!/bin/bash

set -v

# Source folder name for the lab
export SERVICE_SRC=frontend

# Add project id to the env variables in app.yaml
sed -i -e "s/GOOGLE_CLOUD_PROJECT/${GOOGLE_CLOUD_PROJECT}/" ../${SERVICE_SRC}/app.yaml

# Set the region
gcloud config set compute/region europe-west1

# Deploy to App Engine
gcloud app deploy ../${SERVICE_SRC}/app.yaml -q
