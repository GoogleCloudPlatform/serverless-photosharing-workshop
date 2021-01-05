package fn;

import com.google.cloud.functions.*;
import com.google.cloud.vision.v1.*;
import com.google.cloud.vision.v1.Feature.Type;
import com.google.protobuf.ByteString;
import com.google.cloud.firestore.*;
import com.google.api.core.ApiFuture;

import java.io.*;
import java.util.*;
import java.util.stream.*;
import java.util.logging.Logger;

import fn.ImageAnalysis.GCSEvent;

public class ImageAnalysis implements BackgroundFunction<GCSEvent> {
    private static final Logger logger = Logger.getLogger(ImageAnalysis.class.getName());

    @Override
    public void accept(GCSEvent event, Context context) throws IOException {
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
            BatchAnnotateImagesResponse response = vision.batchAnnotateImages(requests);

            logger.info("Retrieving response list...");
            List<AnnotateImageResponse> responses = response.getResponsesList();

            if (responses.size() == 0) {
                logger.info("No response received from Vision API.");
                return;
            }

            AnnotateImageResponse res = responses.get(0);
            if (res.hasError()) {
                logger.info("Error: " + res.getError().getMessage());
                return;
            }

            logger.info("Annotations found:");
            List<String> labels = res.getLabelAnnotationsList().stream()
                .map(annotation -> annotation.getDescription())
                .collect(Collectors.toList());
            for (String label: labels) {
                logger.info("- " + label);
            }

            String mainColor = "#FFFFFF";
            ImageProperties imgProps = res.getImagePropertiesAnnotation();
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
            if (res.hasSafeSearchAnnotation()) {
                SafeSearchAnnotation safeSearch = res.getSafeSearchAnnotation();

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

                ApiFuture<WriteResult> result = doc.set(data, SetOptions.merge());
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
