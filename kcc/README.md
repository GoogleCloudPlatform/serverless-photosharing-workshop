TODOs:
- Why blob and not source repo in Terraform?
- Any dependencies between labs? Or very independant labs/projects?
- Blob storage accees as mabenoit@?

```
CONFIG_CONTROLLER_PROJECT_ID=FIXME
gcloud config set project $CONFIG_CONTROLLER_PROJECT_ID
gcloud services enable krmapihosting.googleapis.com \
    container.googleapis.com
CONFIG_CONTROLLER_NAME=FIXME
LOCATION=us-east1 # or us-central1 are supported for now
LOCAL_IP_ADDRESS=$(curl ifconfig.co) # Change this if needed to properly get your local IP address
gcloud anthos config controller create $CONFIG_CONTROLLER_NAME \
    --location=$LOCATION \
    --man-block $LOCAL_IP_ADDRESS
gcloud services enable cloudbilling.googleapis.com
CONFIG_CONTROLLER_SA="$(kubectl get ConfigConnectorContext -n config-control -o jsonpath='{.items[0].spec.googleServiceAccount}')"
ORG_ID=FIXME
BILLING_ACCOUNT_ID=FIXME
gcloud organizations add-iam-policy-binding ${ORG_ID} \
    --member="serviceAccount:${CONFIG_CONTROLLER_SA}" \
    --role='roles/resourcemanager.projectCreator'
gcloud organizations add-iam-policy-binding ${ORG_ID} \
    --member="serviceAccount:${CONFIG_CONTROLLER_SA}" \
    --role='roles/billing.projectManager'
gcloud beta billing accounts add-iam-policy-binding ${BILLING_ACCOUNT_ID} \
    --member="serviceAccount:${CONFIG_CONTROLLER_SA}" \
    --role='roles/billing.user'
```

Intro:
```
kubectl apply -f sourcerepo.yaml
cd ~
mkdir sourcerepo
cd sourcerepo
gcloud source repos clone serverless-photosharing-workshop
cd serverless-photosharing-workshop
git checkout -b main
cp ~/serverless-photosharing-workshop/* -r .
git add . && git commit -am "init"
git push -u origin main
```

Lab1:
```
SA=${CONFIG_CONTROLLER_SA}
PROJECT_ID=${CONFIG_CONTROLLER_PROJECT_ID}
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${SA}" \
    --role "roles/storage.admin"
```

Lab2:
```
SA=${CONFIG_CONTROLLER_SA}
PROJECT_ID=${CONFIG_CONTROLLER_PROJECT_ID}
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${SA}" \
    --role "roles/run.admin"
```