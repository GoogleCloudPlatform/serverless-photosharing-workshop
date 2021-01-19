#!/bin/bash

set -v

# export SERVICE_SRC=thumbnails
# export SERVICE_NAME=${SERVICE_SRC}-service
# export SERVICE_URL="$(gcloud run services list --platform managed --filter=${SERVICE_NAME} --format='value(URL)')"

#gcloud services enable workflows.googleapis.com
gcloud beta workflows deploy thumbnails-workflows --source=thumbnails-workflows.yaml
gcloud beta workflows execute thumbnails-workflows --data='{"thumbnailsUri":"https://thumbnails-service-rqvs6mtotq-ew.a.run.app", "gcsImageUri":"gs://uploaded-pictures-workflows-atamel/atamel.jpg"}'

