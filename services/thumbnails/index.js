const express = require('express');
const bodyParser = require('body-parser');
const im = require('imagemagick');
const Promise = require("bluebird");
const path = require('path');
const {Storage} = require('@google-cloud/storage');
const storage = new Storage();

const app = express();
app.use(bodyParser.json());

app.get('/', async (req, res) => {
    console.log("It works");
    res.status(200).send("Works");
});

app.post('/', async (req, res) => {
    try {
        const pubSubMessage = req.body;
        console.log(`PubSub message: ${JSON.stringify(pubSubMessage)}`);

        const fileEvent = JSON.parse(Buffer.from(pubSubMessage.message.data, 'base64').toString().trim());
        console.log(`Base 64 decoded file event: ${JSON.stringify(fileEvent)}`);
        console.log(`Received thumbnail request for file ${fileEvent.name} from bucket ${fileEvent.bucket}`);

        const bucket = storage.bucket(fileEvent.bucket);
        const thumbBucket = storage.bucket('thumbnail-pictures');

        const localFile = path.resolve('/tmp', fileEvent.name);
        const parsedPath = path.parse(localFile);
        const thumbPath = path.resolve(parsedPath.dir, parsedPath.name) + '_thumb' + parsedPath.ext;

        await bucket.file(fileEvent.name).download({
            destination: localFile
        });
        console.log(`Downloaded picture into ${localFile}`);

        const resize = Promise.promisify(im.resize);
        await resize({
                srcPath: localFile,
                dstPath: thumbPath,
                width: 200,
                height: 200         
        });
        console.log(`Created local thumbnail in ${thumbPath}`);

        await thumbBucket.upload(thumbPath);
        console.log("Uploaded thumbnail to Cloud Storage");

        res.status(204).send(`${fileEvent.name} processed`);
    } catch (err) {
        console.log(`Error: creating the thumbnail: ${err}`);
        console.error(err);
        res.status(500).send(err);
    }
});

const PORT = process.env.PORT || 8080;

app.listen(PORT, () => {
    console.log(`Started thumbnail generator on port ${PORT}`);
});

/*
{"name": "image.png", "bucket": "bucketname"}
{"data": "eyJuYW1lIjogImltYWdlLnBuZyIsICJidWNrZXQiOiAiYnVja2V0bmFtZSJ9"}
*/