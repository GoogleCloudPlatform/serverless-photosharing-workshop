#!/bin/bash

set -v

#gcloud services enable workflows.googleapis.com
gcloud beta workflows deploy garbagecolllector-workflows --source=workflows.yaml
gcloud beta workflows execute garbagecolllector-workflows --data='{"serviceUri":"https://garbage-collector-service-rqvs6mtotq-ew.a.run.app", "gcsImageUri":"gs://uploaded-pictures-workflows-atamel/atamel.jpg"}'

