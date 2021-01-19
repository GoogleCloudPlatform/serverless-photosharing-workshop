#!/bin/bash

set -v

#gcloud services enable workflows.googleapis.com
gcloud beta workflows deploy collage-workflows --source=workflows.yaml
gcloud beta workflows execute collage-workflows --data='{"serviceUri":"https://collage-service-rqvs6mtotq-ew.a.run.app"}'

