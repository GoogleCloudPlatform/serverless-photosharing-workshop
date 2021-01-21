#!/bin/bash

set -v

#gcloud services enable workflows.googleapis.com
gcloud beta workflows deploy picadaily-workflows --source=workflows.yaml
gcloud beta workflows execute picadaily-workflows \
  --data='{"thumbnailUri":"https://thumbnails-service-rqvs6mtotq-ew.a.run.app","collageUri":"https://collage-service-rqvs6mtotq-ew.a.run.app","garbageCollectorUri":"https://garbage-collector-service-rqvs6mtotq-ew.a.run.app","transformDataUri":"https://europe-west1-pic-a-daily-298110.cloudfunctions.net/vision-data-transform", "bucket":"uploaded-pictures-workflows-atamel","file":"atamel.jpg","eventType":"OBJECT_FINALIZE"}'