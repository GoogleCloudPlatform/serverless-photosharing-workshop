package services;

import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;

import com.google.api.core.ApiFuture;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.MetadataConfig;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.FirestoreOptions;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.storage.Blob;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import magick.ImageInfo;
import magick.MagickImage;
import magick.MontageInfo;

@SpringBootApplication
@RestController
public class CollageService {

    String projectID = MetadataConfig.getProjectId();

    @Value("${BUCKET_THUMBNAILS}")
    String thumbnails;

    @RequestMapping("/")
    public void collage() throws Exception {
    
    // get current Project ID
    System.out.println("Project ID = " + projectID);
    System.out.println("Thumbnails Bucket = " + thumbnails);

    // access collection group in Firestore
    Firestore fs = FirestoreOptions.getDefaultInstance().toBuilder()
        .setProjectId(projectID)
        .setCredentials(GoogleCredentials.getApplicationDefault())
        .build().getService();
    ApiFuture<QuerySnapshot> query = fs.collectionGroup("pictures")
        .whereEqualTo("thumbnail",Boolean.TRUE)
        .orderBy("created", Query.Direction.DESCENDING)
        .limit(4).get();
    List<QueryDocumentSnapshot> documents = query.get().getDocuments();
    Storage storage = StorageOptions.newBuilder()
        .setProjectId(projectID)
        .setCredentials(GoogleCredentials.getApplicationDefault())
        .build()
        .getService();

    // how items did we get
    int docSize = documents.size();

    // thumbnails downloading
    MagickImage[] imagesInfos = new MagickImage[docSize];
    System.out.println(String.format("Collage of %d images:", docSize));
    for (int pictureIndex = 0 ; pictureIndex < docSize ; pictureIndex++) {
        Blob pictureBlob = storage.get(thumbnails, documents.get(pictureIndex).getId());
        String pictureName = pictureBlob.getName();
        System.out.println(pictureName);
        pictureBlob.downloadTo(Paths.get("/tmp/" + pictureName));
        ImageInfo imgInfo = new ImageInfo("/tmp/" + pictureName);
        imagesInfos[pictureIndex] = new MagickImage(imgInfo);
    }
    //picture creation from thumbnails
    MagickImage collage = new MagickImage(imagesInfos);
    ImageInfo imageInfo = new ImageInfo("/tmp/collage.png");
    imageInfo.setTile("2x2");
    MontageInfo montageInfo = new MontageInfo(imageInfo);
    collage.setFileName("/tmp/collage.png");
    collage = collage.montageImages(montageInfo);
    collage.writeImage(imageInfo);
    BlobId blobId = BlobId.of(thumbnails, "collage.png");
    BlobInfo blobInfo = BlobInfo.newBuilder(blobId).setContentType("image/png").build();
    storage.create(blobInfo, Files.readAllBytes(Paths.get("/tmp/collage.png")));
 }
  public static void main(String[] args) {
    SpringApplication.run(CollageService.class, args);
  }
}