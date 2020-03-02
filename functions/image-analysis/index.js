const vision = require('@google-cloud/vision');
const Storage = require('@google-cloud/storage');
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
            });

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