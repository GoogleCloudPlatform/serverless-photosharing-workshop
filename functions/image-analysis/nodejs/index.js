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
const vision = require('@google-cloud/vision');
const Firestore = require('@google-cloud/firestore');

const client = new vision.ImageAnnotatorClient();

exports.vision_analysis = async (event, context) => {
    console.log(`Event: ${JSON.stringify(event)}`);

    const filename = event.name;
    const filebucket = event.bucket;

    console.log(`New picture uploaded ${filename} in ${filebucket}`);

    const request = {
        image: { source: { imageUri: `gs://${filebucket}/${filename}` } },
        features: [
            { type: 'LABEL_DETECTION' },
            { type: 'IMAGE_PROPERTIES' },
            { type: 'SAFE_SEARCH_DETECTION' }
        ]
    };

    // invoking the Vision API
    const [response] = await client.annotateImage(request);
    console.log(`Raw vision output for: ${filename}: ${JSON.stringify(response)}`);

    if (response.error === null) {
        // listing the labels found in the picture
        const labels = response.labelAnnotations
            .sort((ann1, ann2) => ann2.score - ann1.score)
            .map(ann => ann.description)
        console.log(`Labels: ${labels.join(', ')}`);

        // retrieving the dominant color of the picture
        const color = response.imagePropertiesAnnotation.dominantColors.colors
            .sort((c1, c2) => c2.score - c1.score)[0].color;
        const colorHex = decColorToHex(color.red, color.green, color.blue);
        console.log(`Colors: ${colorHex}`);

        // determining if the picture is safe to show
        const safeSearch = response.safeSearchAnnotation;
        const isSafe = ["adult", "spoof", "medical", "violence", "racy"].every(k =>
            !['LIKELY', 'VERY_LIKELY'].includes(safeSearch[k]));
        console.log(`Safe? ${isSafe}`);

        // if the picture is safe to display, store it in Firestore
        if (isSafe) {
            const pictureStore = new Firestore().collection('pictures');

            const doc = pictureStore.doc(filename);
            await doc.set({
                labels: labels,
                color: colorHex,
                created: Firestore.Timestamp.now()
            }, {merge: true});

            console.log("Stored metadata in Firestore");
        }
    } else {
        throw new Error(`Vision API error: code ${response.error.code}, message: "${response.error.message}"`);
    }
};

function decColorToHex(r, g, b) {
    return '#' + Number(r).toString(16).padStart(2, '0') +
                 Number(g).toString(16).padStart(2, '0') +
                 Number(b).toString(16).padStart(2, '0');
}