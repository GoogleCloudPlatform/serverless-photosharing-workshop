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
package services;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutionException;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.stream.*;
import java.util.stream.Collectors;

import javax.annotation.PostConstruct;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import services.actuator.StartupCheck;

import com.google.cloud.vision.v1.*;
import com.google.cloud.vision.v1.Feature.Type;
import com.google.cloud.firestore.*;
import com.google.api.core.ApiFuture;

@RestController
public class EventController {
    private static final Logger logger = LoggerFactory.getLogger(EventController.class);
    
  private static final List<String> requiredFields = Arrays.asList("ce-id", "ce-source", "ce-type", "ce-specversion");

  @PostConstruct
  public void init() {
    logger.info("ImageAnalysisApplication: EventController Post Construct Initializer " + new SimpleDateFormat("HH:mm:ss.SSS").format(new java.util.Date(System.currentTimeMillis())));
    logger.info("ImageAnalysisApplication: EventController Post Construct - Enable StartupCheck can be enabled");

    StartupCheck.up();
  }

  @GetMapping("start")
  String start(){
    logger.info("ImageAnalysisApplication: EventController - Executed start endpoint request " + new SimpleDateFormat("HH:mm:ss.SSS").format(new java.util.Date(System.currentTimeMillis())));
    return "EventController started";
  }

  @RequestMapping(value = "/", method = RequestMethod.POST)
  public ResponseEntity<String> receiveMessage(
    @RequestBody Map<String, Object> body, @RequestHeader Map<String, String> headers) throws IOException, InterruptedException, ExecutionException {

    // Validate the number of available processors
    logger.info("EventController: Active processors: " + Runtime.getRuntime().availableProcessors()); 

    System.out.println("Header elements");
    for (String field : requiredFields) {
      if (headers.get(field) == null) {
        String msg = String.format("Missing expected header: %s.", field);
        System.out.println(msg);
        return new ResponseEntity<String>(msg, HttpStatus.BAD_REQUEST);
      } else {
        System.out.println(field + " : " + headers.get(field));
      }
    }

    System.out.println("Body elements");
    for (String bodyField : body.keySet()) {
      System.out.println(bodyField + " : " + body.get(bodyField));
    }

    if (headers.get("ce-subject") == null) {
      String msg = "Missing expected header: ce-subject.";
      System.out.println(msg);
      return new ResponseEntity<String>(msg, HttpStatus.BAD_REQUEST);
    }

    String ceSubject = headers.get("ce-subject");
    String msg = "Detected change in Cloud Storage bucket: (ce-subject) : " + ceSubject;
    System.out.println(msg);

    String fileName = (String)body.get("name");
    String bucketName = (String)body.get("bucket");

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
            return new ResponseEntity<String>(msg, HttpStatus.BAD_REQUEST);
        }

        AnnotateImageResponse response = responses.get(0);
        if (response.hasError()) {
            logger.info("Error: " + response.getError().getMessage());
            return new ResponseEntity<String>(msg, HttpStatus.BAD_REQUEST);
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

    return new ResponseEntity<String>(msg, HttpStatus.OK);
  }


  private static String rgbHex(float red, float green, float blue) {
    return String.format("#%02x%02x%02x", (int)red, (int)green, (int)blue);
  }

}
// [END eventarc_audit_storage_handler]
