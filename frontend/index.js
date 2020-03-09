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
const Firestore = require('@google-cloud/firestore');
const dayjs = require('dayjs');
const relativeTime = require('dayjs/plugin/relativeTime')
dayjs.extend(relativeTime)

const app = express();
app.use(express.static('public'));

app.get('/', express.static('index.html'));

app.get('/api/pictures', async (req, res) => {
    console.log('Retrieving list of pictures');

    const thumbnails = [];
    const pictureStore = new Firestore().collection('pictures');
    const snapshot = await pictureStore.orderBy('created', 'desc').get();

    if (snapshot.empty) {
        console.log('No pictures found');
    } else {
        snapshot.forEach(doc => {
            const pic = doc.data();
            thumbnails.push({
                name: doc.id,
                labels: pic.labels,
                color: pic.color,
                created: dayjs(pic.created.toDate()).fromNow()
            });
        });
    }
    console.table(thumbnails);
    res.send(thumbnails);
})

const PORT = process.env.PORT || 8080;

app.listen(PORT, () => {
    console.log(`Started collage service on port ${PORT}`);
});
