package services;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.FirestoreOptions;
import com.google.cloud.firestore.SetOptions;
import com.google.cloud.firestore.WriteResult;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class EventService {

  public ApiFuture<WriteResult> storeImage(String fileName, List<String> labels, String mainColor) {
    FirestoreOptions firestoreOptions = FirestoreOptions.getDefaultInstance();
    Firestore pictureStore = firestoreOptions.getService();

    DocumentReference doc = pictureStore.collection("pictures").document(fileName);

    Map<String, Object> data = new HashMap<>();
    data.put("labels", labels);
    data.put("color", mainColor);
    data.put("created", new Date());

    return doc.set(data, SetOptions.merge());
  }

}
