#!/bin/bash

set -v

#gcloud services enable workflows.googleapis.com
gcloud beta workflows deploy picadaily-workflows --source=workflows.yaml
gcloud beta workflows execute picadaily-workflows \
  --data='{"thumbnailUri":"https://thumbnails-service-rqvs6mtotq-ew.a.run.app","gcsImageUri":"gs://uploaded-pictures-workflows-atamel/atamel.jpg","collageUri":"https://collage-service-rqvs6mtotq-ew.a.run.app"}'

