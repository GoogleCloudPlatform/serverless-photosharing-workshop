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
package p

import (
	"encoding/json"
	"fmt"
	"sort"

	pb "google.golang.org/genproto/googleapis/cloud/vision/v1"
)

type visionResponse struct {
	*pb.AnnotateImageResponse
}

// toJSON returns a JSON representation of a response
func (o *visionResponse) toJSON() string {
	b, err := json.Marshal(o)
	if err != nil {
		return "## error marshalling data ##"
	}
	return string(b)
}

// byScore implements sort.Interface based on the Score field
type byScore []*pb.EntityAnnotation

func (o byScore) Len() int           { return len(o) }
func (o byScore) Swap(i, j int)      { o[i], o[j] = o[j], o[i] }
func (o byScore) Less(i, j int) bool { return o[i].Score > o[j].Score }

// getLabels returns the labels found in the response ordered by descending score
func (o *visionResponse) getLabels() (labels []string) {
	sort.Sort(byScore(o.LabelAnnotations))
	for _, label := range o.LabelAnnotations {
		labels = append(labels, label.Description)
	}
	return
}

// getDominantColor returns an Hex representation of the dominant color in the image
func (o *visionResponse) getDominantColor() (hex string) {
	var bestScore float32
	var bestColor *pb.ColorInfo
	for _, color := range o.ImagePropertiesAnnotation.DominantColors.Colors {
		if color.Score > bestScore {
			bestScore = color.Score
			bestColor = color
		}
	}
	if bestColor == nil {
		return "#ffffff"
	}
	return fmt.Sprintf("#%02x%02x%02x", int(bestColor.Color.Red), int(bestColor.Color.Green), int(bestColor.Color.Blue))
}

// isSafe returns true if no field of SafeSearchAnnotation is LIKELY or more
func (o *visionResponse) isSafe() bool {
	safe := o.SafeSearchAnnotation
	for _, value := range []*pb.Likelihood{&safe.Adult, &safe.Medical, &safe.Racy, &safe.Spoof, &safe.Violence} {
		if *value == pb.Likelihood_LIKELY || *value == pb.Likelihood_VERY_LIKELY {
			return false
		}
	}
	return true
}
