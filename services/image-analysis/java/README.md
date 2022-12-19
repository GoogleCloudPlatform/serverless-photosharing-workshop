# Image-analysis Service - Cloud Run Service using Native Spring w/GraalVM

This lab can be executed directly in Cloudshell or your environment of your choice. 

  [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://shell.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/serverless-photosharing-workshop.git)

## Setup Java ecosystem
In order to build native Java app images and containerized native Java applications, please set up GraalVM and the associated Java 17 distributions.

Run the script to download and install GraalVM 22.3 and Java 17
```
# Service code available in the folder below
cd services/image-analysis/java

# Run the script in  Cloudshell - takes aprox 15-20s 
time source ./env/setup.sh
```

Alternatively, run a one-line installer provided by the GraalVM team
```
bash <(curl -sL https://get.graalvm.org/jdk) graalvm-ce-java17-22.3.0
```
## Install the maven wrapper
The Maven Wrapper is an easy way to ensure a user of your Maven build has everything necessary to run your Maven build.

Run the command:
```
mvn wrapper:wrapper
```

## Build the service code and publish images to the container registry

Build the JIT app image:
```
./mvnw package

Start the app locally:
java -jar target/image-analysis-0.0.1.jar
```

Build the Native Java executable: 
```
./mvnw native:compile -Pnative

Test the executable locally:
./target/image-analysis
```

Build the Docker image with the JIT version of the service app:
```
./mvnw spring-boot:build-image
```

Build the Docker image with a Native Java executable:
```
./mvnw spring-boot:build-image -Pnative
```

Check the Docker image sizes:
```
docker images | grep image-analysis
image-analysis-maven-jit                        latest     6751b98f7ebf   42 years ago    329MB
image-analysis-maven-native                     latest     3af942985d65   42 years ago    262MB
```

Start the Docker images locally. The image naming conventions indicate whether the image was built by Maven|Gradle and contains the JIT|NATIVE version
```
docker run --rm image-analysis-maven-jit
docker run --rm image-analysis-maven-native
```

Retrieve the Project ID, as it will be required for the next GCP operations
```
export PROJECT_ID=$(gcloud config get-value project)
echo $PROJECT_ID
```

Tag and push the images to GCR:
```
docker tag image-analysis-maven-jit gcr.io/${PROJECT_ID}/image-analysis-maven-jit
docker tag image-analysis-maven-native gcr.io/${PROJECT_ID}/image-analysis-maven-native

docker push gcr.io/${PROJECT_ID}/image-analysis-maven-jit
docker push gcr.io/${PROJECT_ID}/image-analysis-maven-native
```

## Deploy and run workshop code

Enable the required APIs:
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

## Create the database

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
SERVICE_ACCOUNT="$(gsutil kms serviceaccount -p ${GOOGLE_CLOUD_PROJECT})"

gcloud projects add-iam-policy-binding ${GOOGLE_CLOUD_PROJECT} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role='roles/pubsub.publisher'
```

Deploy
```
# deploy to Cloud Run
gcloud run deploy image-analysis-jit \
     --image gcr.io/${GOOGLE_CLOUD_PROJECT}/image-analysis-maven-jit \
     --region europe-west1 \
     --memory 2Gi --allow-unauthenticated

gcloud run deploy image-analysis-native \
     --image gcr.io/${GOOGLE_CLOUD_PROJECT}/image-analysis-maven-native \
     --region europe-west1 \
     --memory 2Gi --allow-unauthenticated  

JIT Image deployment:
2022-08-03T20:23:14.534589Z2022-08-03 20:23:14.533 INFO 1 --- [ main] services.ImageAnalysisApplication : Started ImageAnalysisApplication in 3.27 seconds (JVM running for 4.886)

Native Image deployment:
2022-08-03T20:26:03.299194Z2022-08-03 20:26:03.299 INFO 1 --- [ main] services.ImageAnalysisApplication : Started ImageAnalysisApplication in 0.075 seconds (JVM running for 0.077)      
```

Set up Eventarc triggers
```
gcloud eventarc triggers list --location=eu

gcloud eventarc triggers create image-analysis-jit-trigger \
     --destination-run-service=image-analysis-jit \
     --destination-run-region=europe-west1 \
     --location=eu \
     --event-filters="type=google.cloud.storage.object.v1.finalized" \
     --event-filters="bucket=uploaded-pictures-${PROJECT_ID}" \
     --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com

gcloud eventarc triggers create image-analysis-native-trigger \
     --destination-run-service=image-analysis-native \
     --destination-run-region=europe-west1 \
     --location=eu \
     --event-filters="type=google.cloud.storage.object.v1.finalized" \
     --event-filters="bucket=uploaded-pictures-${PROJECT_ID}" \
     --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com     
```

Test the trigger
```
gsutil cp GeekHour.jpeg gs://uploaded-pictures-${GOOGLE_CLOUD_PROJECT}

gcloud logging read "resource.labels.service_name=image-analysis-jit AND textPayload:GeekHour" --format=json
```

--------------------
Log capture
```
gcloud logging read "resource.labels.service_name=image-analysis-jit AND textPayload:GeekHour" --format=json

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
        "configuration_name": "image-analysis-jit",
        "location": "europe-west1",
        "project_id": "optimize-serverless-apps",
        "revision_name": "image-analysis-jit-00001-waf",
        "service_name": "image-analysis-jit"
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
        "configuration_name": "image-analysis-jit",
        "location": "europe-west1",
        "project_id": "optimize-serverless-apps",
        "revision_name": "image-analysis-jit-00001-waf",
        "service_name": "image-analysis-jit"
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
2022-08-04T13:45:24.137495ZPOST200723 B1.1 sAPIs-Google; (+https://developers.google.com/webmasters/APIs-Google.html) https://image-analysis-jit-6hrfwttbsa-ew.a.run.app/?__GCP_CloudEventsMode=GCS_NOTIFICATION
```

