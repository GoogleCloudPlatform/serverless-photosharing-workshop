#!/bin/bash

set -v

#gcloud services enable workflows.googleapis.com
gcloud beta workflows deploy picadaily-workflows --source=workflows.yaml
gcloud beta workflows execute picadaily-workflows \
  --data='{"bucket":"uploaded-pictures-workflows-atamel","file":"atamel.jpg","eventType":"OBJECT_FINALIZE"}'