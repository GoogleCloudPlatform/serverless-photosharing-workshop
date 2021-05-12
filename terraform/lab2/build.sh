#!/bin/bash

set -v

SERVICE_SRC=../../services/thumbnails/nodejs
SERVICE_NAME=thumbnails-service

# Build the container

## Node.js
gcloud builds submit \
  ${SERVICE_SRC} \
  --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/${SERVICE_NAME}