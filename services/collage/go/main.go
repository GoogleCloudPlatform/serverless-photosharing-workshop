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
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"cloud.google.com/go/firestore"
	"cloud.google.com/go/storage"
	"github.com/kelseyhightower/envconfig"
	"gopkg.in/gographics/imagick.v2/imagick"
)

type config struct {
	BucketThumbnails string `split_words:"true"`
	Port             int    `default:"8080"`
}

func main() {
	var env config
	envconfig.Process("", &env)

	http.HandleFunc("/", handleRequest(env))

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

		fireClient, err := firestore.NewClient(ctx, firestore.DetectProjectID)
		if err != nil {
			log.Printf("Failed to get 'pictures' firestore collection: %v", err)
			http.Error(w, "Failed to get 'pictures' firestore collection", http.StatusInternalServerError)
			return
		}

		docs, err := fireClient.Collection("pictures").OrderBy("created", firestore.Desc).Limit(4).Documents(ctx).GetAll()
		if err != nil {
			log.Printf("Failed to get last pictures: %v", err)
			http.Error(w, "Failed to get last pictures", http.StatusInternalServerError)
			return
		}

		if len(docs) != 4 {
			w.WriteHeader(http.StatusNoContent)
			fmt.Fprint(w, "No collage created.")
			return
		}

		storageClient, err := storage.NewClient(ctx)
		if err != nil {
			log.Printf("Error getting storage client: %v", err)
			http.Error(w, "Error getting storage client", http.StatusInternalServerError)
			return
		}

		localFiles := make([]string, 4)

		for i, doc := range docs {
			file := doc.Ref.ID
			localFile := filepath.Join("/tmp", file)
			localFiles[i] = localFile
			err = downloadObject(ctx, storageClient, env.BucketThumbnails, file, localFile)
			if err != nil {
				http.Error(w, "Error downloading image from bucket", http.StatusInternalServerError)
				return
			}
			defer os.Remove(localFile)
		}
		log.Print("Downloaded all thumbnails")

		collagePath := filepath.Join("/tmp", "collage.png")

		imagick.Initialize()
		defer imagick.Terminate()

		args := []string{"convert",
			"(", localFiles[0], localFiles[1], "+append", ")",
			"(", localFiles[2], localFiles[3], "+append", ")",
			"-size", "400x400", "xc:none", "-background", "none", "-append", "-trim",
			collagePath,
		}

		_, err = imagick.ConvertImageCommand(args)
		if err != nil {
			log.Printf("Error during convert command: %v", err)
			http.Error(w, "Error creating collage", http.StatusInternalServerError)
			return
		}

		err = uploadObject(ctx, storageClient, collagePath, env.BucketThumbnails, "collage.png")
		if err != nil {
			http.Error(w, "Error creating collage.png on bucket", http.StatusInternalServerError)
			return
		}
		defer os.Remove(collagePath)

		w.WriteHeader(http.StatusNoContent)
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
