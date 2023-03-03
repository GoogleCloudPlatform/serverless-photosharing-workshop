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
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class EventService {

  private final FirestoreOptions firestoreOptions;
  private final Firestore firestore;

  public EventService() {
    this.firestoreOptions = FirestoreOptions.getDefaultInstance();
    this.firestore = firestoreOptions.getService();
  }
  public EventService(FirestoreOptions firestoreOptions, Firestore firestore) {
    this.firestoreOptions = firestoreOptions;
    this.firestore = firestore;
  }

  public ApiFuture<WriteResult> storeImage(String fileName, List<String> labels, String mainColor) {
    DocumentReference doc = firestore.collection("pictures").document(fileName);

    Map<String, Object> data = new HashMap<>();
    data.put("labels", labels);
    data.put("color", mainColor);
    data.put("created", new Date());

    return doc.set(data, SetOptions.merge());
  }

}
