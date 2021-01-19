#!/bin/bash

set -v

#gcloud services enable workflows.googleapis.com
gcloud beta workflows deploy thumbnails-workflows --source=workflows.yaml
gcloud beta workflows execute thumbnails-workflows --data='{"serviceUri":"https://thumbnails-service-rqvs6mtotq-ew.a.run.app", "gcsImageUri":"gs://uploaded-pictures-workflows-atamel/atamel.jpg"}'

