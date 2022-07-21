/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package fn;

import com.google.cloud.functions.*;
import com.google.cloud.vision.v1.*;
import com.google.cloud.vision.v1.Feature.Type;
import com.google.cloud.firestore.*;
import com.google.api.core.ApiFuture;

import java.io.*;
import java.util.*;
import java.util.stream.*;
import java.util.concurrent.*;
import java.util.logging.Logger;

import fn.ImageAnalysis.GCSEvent;

public class ImageAnalysis implements BackgroundFunction<GCSEvent> {
    private static final Logger logger = Logger.getLogger(ImageAnalysis.class.getName());

    @Override
    public void accept(GCSEvent event, Context context) 
            throws IOException, InterruptedException, ExecutionException {
        String fileName = event.name;
        String bucketName = event.bucket;

        logger.info("New picture uploaded " + fileName);

        try (ImageAnnotatorClient vision = ImageAnnotatorClient.create()) {
            List<AnnotateImageRequest> requests = new ArrayList<>();
            
            ImageSource imageSource = ImageSource.newBuilder()
                .setGcsImageUri("gs://" + bucketName + "/" + fileName)
                .build();

            Image image = Image.newBuilder()
                .setSource(imageSource)
                .build();

            Feature featureLabel = Feature.newBuilder()
                .setType(Type.LABEL_DETECTION)
                .build();
            Feature featureImageProps = Feature.newBuilder()
                .setType(Type.IMAGE_PROPERTIES)
                .build();
            Feature featureSafeSearch = Feature.newBuilder()
                .setType(Type.SAFE_SEARCH_DETECTION)
                .build();
                
            AnnotateImageRequest request = AnnotateImageRequest.newBuilder()
                .addFeatures(featureLabel)
                .addFeatures(featureImageProps)
                .addFeatures(featureSafeSearch)
                .setImage(image)
                .build();
            
            requests.add(request);

            logger.info("Calling the Vision API...");
            BatchAnnotateImagesResponse result = vision.batchAnnotateImages(requests);
            List<AnnotateImageResponse> responses = result.getResponsesList();

            if (responses.size() == 0) {
                logger.info("No response received from Vision API.");
                return;
            }

            AnnotateImageResponse response = responses.get(0);
            if (response.hasError()) {
                logger.info("Error: " + response.getError().getMessage());
                return;
            }

            List<String> labels = response.getLabelAnnotationsList().stream()
                .map(annotation -> annotation.getDescription())
                .collect(Collectors.toList());
            logger.info("Annotations found:");
            for (String label: labels) {
                logger.info("- " + label);
            }

            String mainColor = "#FFFFFF";
            ImageProperties imgProps = response.getImagePropertiesAnnotation();
            if (imgProps.hasDominantColors()) {
                DominantColorsAnnotation colorsAnn = imgProps.getDominantColors();
                ColorInfo colorInfo = colorsAnn.getColors(0);

                mainColor = rgbHex(
                    colorInfo.getColor().getRed(), 
                    colorInfo.getColor().getGreen(), 
                    colorInfo.getColor().getBlue());

                logger.info("Color: " + mainColor);
            }

            boolean isSafe = false;
            if (response.hasSafeSearchAnnotation()) {
                SafeSearchAnnotation safeSearch = response.getSafeSearchAnnotation();

                isSafe = Stream.of(
                    safeSearch.getAdult(), safeSearch.getMedical(), safeSearch.getRacy(),
                    safeSearch.getSpoof(), safeSearch.getViolence())
                .allMatch( likelihood -> 
                    likelihood != Likelihood.LIKELY && likelihood != Likelihood.VERY_LIKELY
                );

                logger.info("Safe? " + isSafe);
            }

            // Saving result to Firestore
            if (isSafe) {
                FirestoreOptions firestoreOptions = FirestoreOptions.getDefaultInstance();
                Firestore pictureStore = firestoreOptions.getService();

                DocumentReference doc = pictureStore.collection("pictures").document(fileName);

                Map<String, Object> data = new HashMap<>();
                data.put("labels", labels);
                data.put("color", mainColor);
                data.put("created", new Date());

                ApiFuture<WriteResult> writeResult = doc.set(data, SetOptions.merge());

                logger.info("Picture metadata saved in Firestore at " + writeResult.get().getUpdateTime());
            }
        }
    }

    private static String rgbHex(float red, float green, float blue) {
        return String.format("#%02x%02x%02x", (int)red, (int)green, (int)blue);
    }

    public static class GCSEvent {
        String bucket;
        String name;
    }
}
