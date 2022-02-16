#!/bin/bash

set -v

PROJECT=FIXME

NAMESPACE=config-control

# Enable services
kubectl apply -f services.yaml -n $NAMESPACE

# Create a public multi-region bucket with uniform level access
export BUCKET_NAME=uploaded-pictures-${PROJECT}
export BUCKET_LOCATION=EU # EU, USA, ASIA
sed -i "s/BUCKET_NAME/$BUCKET_NAME/g;s/BUCKET_LOCATION/$BUCKET_LOCATION/g" storage.yaml
kubectl apply -f storage.yaml -n $NAMESPACE

# Create an App Engine app (requirement for Firestore) and Firestore
export REGION=europe-west2
gcloud app create --region=${REGION}
gcloud firestore databases create --region=${REGION}

# Create Firestore index
kubectl apply -f firestore.yaml  -n $NAMESPACE

# Function
kubectl apply -f function.yaml -n $NAMESPACE
# gcloud beta functions add-iam-policy-binding picture-uploaded --member=allUsers --role=roles/cloudfunctions.invoker