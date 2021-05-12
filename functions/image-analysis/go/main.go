// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package p contains a Google Cloud Storage Cloud Function.
package p

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	vision "cloud.google.com/go/vision/apiv1"
	"github.com/pkg/errors"
	pb "google.golang.org/genproto/googleapis/cloud/vision/v1"
)

// GCSEvent is the payload of a GCS event. Please refer to the docs for
// additional information regarding GCS events.
type GCSEvent struct {
	Bucket string `json:"bucket"`
	Name   string `json:"name"`
}

// firestorePicture is the structure of a `pictures` document in Firestore
type firestorePicture struct {
	Labels []string `firestore:"labels"`
	Color  string   `firestore:"color"`
	// Created value will be set with the time of creation on the server (firestore) side
	// see https://godoc.org/cloud.google.com/go/firestore#DocumentRef.Create
	Created time.Time `firestore:"created,serverTimestamp"`
}

/* VisionAnalysis creates a thumbnail when a file is changed in a Cloud Storage bucket.
   You can deploy this function to Cloud Function with the command:
   gcloud functions deploy image-analysis \
	 --region $YOUR_REGION \
	 --entry-point VisionAnalysis \
	 --trigger-bucket $YOUR_SOURCE_BUCKET \
	 --runtime go111 \
	 --no-allow-unauthenticated
*/
func VisionAnalysis(ctx context.Context, e GCSEvent) error {
	log.Printf("Event: %#v", e)

	filename := e.Name
	filebucket := e.Bucket
	log.Printf("New picture uploaded %s in %s", filename, filebucket)

	client, err := vision.NewImageAnnotatorClient(ctx)
	if err != nil {
		log.Printf("Failed to create client: %v", err)
		return errors.New("Failed to create CloudVision client")
	}
	defer client.Close()

	request := &pb.AnnotateImageRequest{
		Image: &pb.Image{
			Source: &pb.ImageSource{
				ImageUri: fmt.Sprintf("gs://%s/%s", filebucket, filename),
			},
		},
		Features: []*pb.Feature{
			{Type: pb.Feature_LABEL_DETECTION},
			{Type: pb.Feature_IMAGE_PROPERTIES},
			{Type: pb.Feature_SAFE_SEARCH_DETECTION},
		},
	}

	r, err := client.AnnotateImage(ctx, request)
	if err != nil {
		log.Printf("Failed annotate image: %v", err)
		return fmt.Errorf("Vision API error: code %d, message: '%s'", r.Error.Code, r.Error.Message)
	}

	resp := visionResponse{r}
	log.Printf("Raw vision output for: %s: %s", filename, resp.toJSON())

	labels := resp.getLabels()
	log.Printf("Labels: %s", strings.Join(labels, ", "))

	color := resp.getDominantColor()
	log.Printf("Color: %s", color)

	if !resp.isSafe() {
		return nil
	}

	// if the picture is safe to display, store it in Firestore
	pictureStore, err := firestore.NewClient(ctx, firestore.DetectProjectID)
	if err != nil {
		log.Printf("Failed to get 'pictures' firestore collection: %v", err)
		return errors.New("Failed to get 'pictures' firestore collection")
	}

	_, err = pictureStore.Doc("pictures/"+filename).Create(ctx, firestorePicture{
		Labels: labels,
		Color:  color,
	})
	if err != nil {
		log.Printf("Failed to add picture in firestore: %v", err)
		return errors.New("Failed to add picture in firestore")
	}

	return nil
}
