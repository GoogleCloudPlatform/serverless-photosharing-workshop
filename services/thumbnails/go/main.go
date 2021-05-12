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
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"cloud.google.com/go/pubsub"
	"cloud.google.com/go/storage"
	"github.com/kelseyhightower/envconfig"
	"gopkg.in/gographics/imagick.v2/imagick"
)

type config struct {
	BucketThumbnails string `split_words:"true"`
	Port             int    `default:"8080"`
}

const (
	originalDir  = "/tmp/original"
	thumbnailDir = "/tmp/thumbnail"
)

func main() {
	var env config
	envconfig.Process("", &env)

	http.HandleFunc("/", handleRequest(env))

	os.MkdirAll(originalDir, 0755)
	os.MkdirAll(thumbnailDir, 0755)

	log.Printf("Start listening on port %d", env.Port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", env.Port), nil))
}

func handleRequest(env config) func(w http.ResponseWriter, r *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		if r.URL.Path != "/" {
			http.Error(w, "404 not found.", http.StatusNotFound)
			return
		}
		if r.Method != "POST" {
			http.Error(w, "404 Not Found.", http.StatusNotFound)
			return
		}
		log.Printf("Got POST on /")

		defer r.Body.Close()
		pubSubMessage, err := ioutil.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Error reading body", http.StatusInternalServerError)
			return
		}
		log.Printf("Body: %s", string(pubSubMessage))

		var m struct {
			Message pubsub.Message `json:"message"`
		}
		err = json.Unmarshal(pubSubMessage, &m)
		if err != nil {
			log.Printf("Error reading pub/sub message: %v", err)
			http.Error(w, "Error reading pub/sub message", http.StatusInternalServerError)
			return
		}

		var obj struct {
			Bucket string `json:"bucket"`
			Name   string `json:"name"`
		}
		err = json.Unmarshal(m.Message.Data, &obj)
		if err != nil {
			log.Printf("Error reading pub/sub data: %v", err)
			http.Error(w, "Error reading pub/sub data", http.StatusInternalServerError)
			return
		}

		storageClient, err := storage.NewClient(ctx)
		if err != nil {
			log.Printf("Error getting storage client: %v", err)
			http.Error(w, "Error getting storage client", http.StatusInternalServerError)
			return
		}

		originalFile := filepath.Join(originalDir, obj.Name)
		err = downloadObject(ctx, storageClient, obj.Bucket, obj.Name, originalFile)
		if err != nil {
			http.Error(w, "Error downloading image from bucket", http.StatusInternalServerError)
			return
		}
		defer os.Remove(originalFile)
		log.Printf("Downloaded picture into %s", originalFile)

		imagick.Initialize()
		defer imagick.Terminate()
		mw := imagick.NewMagickWand()
		defer mw.Destroy()

		err = mw.ReadImage(originalFile)
		if err != nil {
			http.Error(w, "Error reading image from Image Magick", http.StatusInternalServerError)
			return
		}
		err = mw.ThumbnailImage(400, 400)
		if err != nil {
			http.Error(w, "Error creating thumbnail with Image Magick", http.StatusInternalServerError)
			return
		}

		thumbFile := filepath.Join(thumbnailDir, obj.Name)
		err = mw.WriteImage(thumbFile)
		if err != nil {
			http.Error(w, "Error saving thumbnail", http.StatusInternalServerError)
			return
		}
		defer os.Remove(thumbFile)
		log.Printf("Created local thumbnail in %s", thumbFile)

		err = uploadObject(ctx, storageClient, thumbFile, env.BucketThumbnails, obj.Name)
		if err != nil {
			http.Error(w, "Error creating thumbnail on bucket", http.StatusInternalServerError)
			return
		}

		log.Printf("Uploaded thumbnail to Cloud Storage bucket %s", env.BucketThumbnails)
		w.WriteHeader(http.StatusNoContent)
		fmt.Fprintf(w, "%s processed", obj.Name)
	}
}

// downloadObject copies an object of a given bucket to a local file
func downloadObject(ctx context.Context, client *storage.Client, bucket string, name string, filename string) error {
	src, err := client.Bucket(bucket).Object(name).NewReader(ctx)
	if err != nil {
		log.Printf("Error creating reader on object: %v", err)
		return err
	}
	defer src.Close()

	dest, err := os.Create(filename)
	if err != nil {
		log.Printf("Error creating destination file: %v", err)
		return err
	}
	defer dest.Close()

	_, err = io.Copy(dest, src)
	if err != nil {
		log.Printf("Error copying object to file: %v", err)
		return err
	}
	return nil
}

// uploadObject copies a local file into an object of a given bucket
func uploadObject(ctx context.Context, client *storage.Client, filename string, bucket string, name string) error {
	src, err := os.Open(filename)
	if err != nil {
		log.Printf("Error opening source file: %v", err)
		return err
	}
	defer src.Close()

	dest := client.Bucket(bucket).Object(name).NewWriter(ctx)
	defer dest.Close()

	_, err = io.Copy(dest, src)
	if err != nil {
		log.Printf("Error copying file to object: %v", err)
		return err
	}
	return nil
}
