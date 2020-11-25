// Copyright 2020 Google LLC
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
const express = require('express');
const bodyParser = require('body-parser');
const Promise = require("bluebird");
const {Storage} = require('@google-cloud/storage');
const storage = new Storage();
const Firestore = require('@google-cloud/firestore');
const { HTTP } = require("cloudevents");
const {toLogEntryData} = require('@google/events/cloud/audit/v1/LogEntryData');

const app = express();
app.use(bodyParser.json());

const EVENT_TYPE_AUDITLOG = 'google.cloud.audit.log.v1.written';
const bucketImages = process.env.BUCKET_IMAGES;
const bucketThumbnails = process.env.BUCKET_THUMBNAILS;

app.post('/', async (req, res) => {
    try {
        const cloudEvent = HTTP.toEvent({ headers: req.headers, body: req.body });
        console.log(cloudEvent);

        if (EVENT_TYPE_AUDITLOG != cloudEvent.type)
        {
            console.log(`Event type '${cloudEvent.type}' is not '${EVENT_TYPE_AUDITLOG}', ignoring.`);
            res.status(200).send();
            return;
        }

        //"protoPayload" : {"resourceName":"projects/_/buckets/events-atamel-images-input/objects/atamel.jpg}";
        const logEntryData = toLogEntryData(cloudEvent.data);
        console.log(logEntryData);

        const tokens = logEntryData.protoPayload.resourceName.split('/');
        const bucket = tokens[3];
        const objectName = tokens[5];

        if (bucketImages != bucket)
        {
            console.log(`Bucket '${bucket}' is not same as '${bucketImages}', ignoring.`);
            res.status(200).send();
            return;
        }

        async function deleteFromThumbnails() {
            await storage.bucket(bucketThumbnails).file(objectName).delete();

            console.log(`Deleted '${objectName}' from bucket '${bucketThumbnails}'.`);
        }
        deleteFromThumbnails().catch(err => console.log(`Failed to delete '${objectName}' from bucket '${bucketThumbnails}': ${err}.`));

        async function deleteFromFirestore() {
            const pictureStore = new Firestore().collection('pictures');
            const docRef = pictureStore.doc(objectName);
            await docRef.delete();

            console.log(`Deleted '${objectName}' from Firestore collection 'pictures'`);
        }
        deleteFromFirestore().catch(err => console.log(`Failed to delete '${objectName}' from Firestore: ${err}.`));

        res.status(200).send(`Processed '${objectName}'.`);
    } catch (err) {
        console.log(`Error: ${err}`);
        res.status(500).send(err);
    }
});

const PORT = process.env.PORT || 8080;

app.listen(PORT, () => {
    if (!bucketImages) throw new Error("BUCKET_IMAGES not set");
    if (!bucketThumbnails) throw new Error("BUCKET_THUMBNAILS not set");
    console.log(`Started service on port ${PORT}`);
});
