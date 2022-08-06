# Image-analysis Service - Cloud Run Service using Native Spring w/GraalVM

## Build code and publish images

Build the JVM app image:
```
./mvnw package -Pjvm

Test the app locally:
java -jar target/image-analysis-0.0.1.jar
```

Build the Native Java executable: 
```
./mvnw package -Pnative

Test the executable locally:
./target/image-analysis
```

Build the Docker image with a JVM app:
```
./mvnw package -Pjvm-image
```

Build the Docker image with a Native Java executable:
```
./mvnw package -Pnative-image
```

Check the Docker image sizes:
```
docker images | grep analysis
image-analysis-jvm                  r17   6b44e0357e26   42 years ago    336MB
image-analysis-native               r17   cfd3bc296c65   42 years ago    72.1MB
```

Run the Docker images locally:
```
docker run --rm image-analysis-jvm:r17
docker run --rm image-analysis-native:r17
```

Tag and push the images to GCR:
```
docker tag image-analysis-jvm:r17 gcr.io/<Your-Project-ID>/image-analysis-jvm:r17
docker tag image-analysis-native:r17 gcr.io/<Your-Project-ID>/image-analysis-native:r17

docker push gcr.io/<Your-Project-ID>/image-analysis-jvm:r17
docker push  gcr.io/<Your-Project-ID>/image-analysis-native:r17
```

## Deploy and run workshop code

Enable the requried APIs:
```
gcloud services enable vision.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com 
gcloud services enable run.googleapis.com
```

Create the bucket:
```
# get the Project_ID
export PROJECT_ID=$(gcloud config list --format 'value(core.project)')
  or 
export PROJECT_ID=$(gcloud config get-value project)
# get the Project_Number
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

# set project env var
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project)

# Create the GCS bucket
export BUCKET_PICTURES=uploaded-pictures-${GOOGLE_CLOUD_PROJECT}
gsutil mb -l EU gs://${BUCKET_PICTURES}
gsutil uniformbucketlevelaccess set on gs://${BUCKET_PICTURES}
gsutil iam ch allUsers:objectViewer gs://${BUCKET_PICTURES}
```

# Create the database

Instructions for configuring cloud Firestore available [here](https://codelabs.developers.google.com/codelabs/cloud-picadaily-lab1?hl=en&continue=https%3A%2F%2Fcodelabs.developers.google.com%2Fserverless-workshop%2F#8)


Set config variables
```
gcloud config set project ${GOOGLE_CLOUD_PROJECT}
gcloud config set run/region 
gcloud config set run/platform managed
gcloud config set eventarc/location europ-west1
```

Grant `pubsub.publisher` to Cloud Storage service account
```
SERVICE_ACCOUNT="$(gsutil kms serviceaccount -p optimize-serverless-apps)"

gcloud projects add-iam-policy-binding ${GOOGLE_CLOUD_PROJECT} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role='roles/pubsub.publisher'
```

Tag / upload / deploy
```
docker tag image-analysis-jvm:r17 gcr.io/${GOOGLE_CLOUD_PROJECT}/image-analysis-jvm:r17
docker tag image-analysis-native:r17 gcr.io/${GOOGLE_CLOUD_PROJECT}/image-analysis-native:r17

# check images

image-analysis-native                                    r17     cfd3bc296c65   42 years ago    72.1MB
gcr.io/<Your-Project-Id>/image-analysis-native    r17     cfd3bc296c65   42 years ago    72.1MB
image-analysis-jvm                                       r17     6b44e0357e26   42 years ago    336MB
gcr.io/Your-Prroject-Id/image-analysis-jvm       r17     6b44e0357e26   42 years ago    336MB

# deploy to Cloud Run

gcloud run deploy image-analysis-jvm \
     --image gcr.io/${GOOGLE_CLOUD_PROJECT}/image-analysis-jvm:r17 \
     --region europe-west1 \
     --memory 2Gi --allow-unauthenticated

gcloud run deploy image-analysis-native \
     --image gcr.io/${GOOGLE_CLOUD_PROJECT}/image-analysis-native:r17 \
     --region europe-west1 \
     --memory 2Gi --allow-unauthenticated  

JVM Image deployment:
2022-08-03T20:23:14.534589Z2022-08-03 20:23:14.533 INFO 1 --- [ main] services.ImageAnalysisApplication : Started ImageAnalysisApplication in 3.27 seconds (JVM running for 4.886)

Native Image deployment:
2022-08-03T20:26:03.299194Z2022-08-03 20:26:03.299 INFO 1 --- [ main] services.ImageAnalysisApplication : Started ImageAnalysisApplication in 0.075 seconds (JVM running for 0.077)      
```

Set up Eventarc triggers
```
gcloud eventarc triggers list --location=eu

gcloud eventarc triggers create image-analysis-jvm-trigger \
     --destination-run-service=image-analysis-jvm \
     --destination-run-region=europe-west1 \
     --location=eu \
     --event-filters="type=google.cloud.storage.object.v1.finalized" \
     --event-filters="bucket=uploaded-pictures-<Your-Project-Id" \
     --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com

gcloud eventarc triggers create image-analysis-native-trigger \
     --destination-run-service=image-analysis-native \
     --destination-run-region=europe-west1 \
     --location=eu \
     --event-filters="type=google.cloud.storage.object.v1.finalized" \
     --event-filters="bucket=uploaded-pictures-optimize-serverless-apps" \
     --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com     
```

Test the trigger
```
gsutil cp GeekHour.jpeg gs://uploaded-pictures-${GOOGLE_CLOUD_PROJECT}

gcloud logging read "resource.labels.service_name=image-analysis-jvm AND textPayload:GeekHour" --format=json
```

--------------------
Log capture
```
gcloud logging read "resource.labels.service_name=image-analysis-jvm AND textPayload:GeekHour" --format=json

...
 {
    "insertId": "62ebcd66000505e81968501a",
    "labels": {
      "instanceId": "00c527f6d474fb398874cbe473887f91c17dd370c7b10c37f1800a80d7fbfbbbc4ee7eb4fd6149691667dee7cb2f59aae11f65b798fbda01d378a74b8c468c2fe8"
    },
    "logName": "projects/optimize-serverless-apps/logs/run.googleapis.com%2Fstdout",
    "receiveTimestamp": "2022-08-04T13:45:10.528219041Z",
    "resource": {
      "labels": {
        "configuration_name": "image-analysis-jvm",
        "location": "europe-west1",
        "project_id": "optimize-serverless-apps",
        "revision_name": "image-analysis-jvm-00001-waf",
        "service_name": "image-analysis-jvm"
      },
      "type": "cloud_run_revision"
    },
    "textPayload": "selfLink : https://www.googleapis.com/storage/v1/b/uploaded-pictures-optimize-serverless-apps/o/GeekHour.jpeg",
    "timestamp": "2022-08-04T13:45:10.329192Z"
  },
  {
    "insertId": "62ebcd66000505dddf95cc89",
    "labels": {
      "instanceId": "00c527f6d474fb398874cbe473887f91c17dd370c7b10c37f1800a80d7fbfbbbc4ee7eb4fd6149691667dee7cb2f59aae11f65b798fbda01d378a74b8c468c2fe8"
    },
    "logName": "projects/optimize-serverless-apps/logs/run.googleapis.com%2Fstdout",
    "receiveTimestamp": "2022-08-04T13:45:10.528219041Z",
    "resource": {
      "labels": {
        "configuration_name": "image-analysis-jvm",
        "location": "europe-west1",
        "project_id": "optimize-serverless-apps",
        "revision_name": "image-analysis-jvm-00001-waf",
        "service_name": "image-analysis-jvm"
      },
      "type": "cloud_run_revision"
    },
    "textPayload": "id : uploaded-pictures-optimize-serverless-apps/GeekHour.jpeg/1659620698262814",
    "timestamp": "2022-08-04T13:45:10.329181Z"
  }
...
```

Log capture - Console
```
Default
2022-08-04T13:45:23.090834Zupdated : 2022-08-04T13:44:58.332Z
Default
2022-08-04T13:45:23.090861ZstorageClass : STANDARD
Default
2022-08-04T13:45:23.090869ZtimeStorageClassUpdated : 2022-08-04T13:44:58.332Z
Default
2022-08-04T13:45:23.090926Zsize : 8062
Default
2022-08-04T13:45:23.090942Zmd5Hash : 6Ywof9Kj21ymWv/nwHlwIw==
Default
2022-08-04T13:45:23.090952ZmediaLink : https://www.googleapis.com/download/storage/v1/b/uploaded-pictures-optimize-serverless-apps/o/GeekHour.jpeg?generation=1659620698262814&alt=media
Default
2022-08-04T13:45:23.090973ZcontentLanguage : en
Default
2022-08-04T13:45:23.090990Zcrc32c : l29Spw==
Default
2022-08-04T13:45:23.091147Zetag : CJ6auvGorfkCEAE=
Default
2022-08-04T13:45:23.091158ZDetected change in Cloud Storage bucket: (ce-subject) : objects/GeekHour.jpeg
Default
2022-08-04T13:45:23.091316Z2022-08-04 13:45:23.091 INFO 1 --- [nio-8080-exec-6] services.EventController : New picture uploaded GeekHour.jpeg
Default
2022-08-04T13:45:23.095471Z2022-08-04 13:45:23.095 INFO 1 --- [nio-8080-exec-6] services.EventController : Calling the Vision API...
Info
2022-08-04T13:45:24.137495ZPOST200723 B1.1 sAPIs-Google; (+https://developers.google.com/webmasters/APIs-Google.html) https://image-analysis-jvm-6hrfwttbsa-ew.a.run.app/?__GCP_CloudEventsMode=GCS_NOTIFICATION
```

