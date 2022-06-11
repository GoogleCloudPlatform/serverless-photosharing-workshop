# Copyright 2022 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import firebase_admin
from firebase_admin import firestore
from google.cloud import vision
from google.protobuf.json_format import MessageToJson
import datetime

# firebase setup
app = firebase_admin.initialize_app()
store = firestore.client()

def decColorToHex(rgb):
    return '#%02x%02x%02x' % rgb

def vision_analysis(event, context):
    print('Event: ' + json.dumps(event))

    #event = json.load(event)
    filename = event['name']
    filebucket = event['bucket']

    print('New picture uploaded ' + filename + ' in ' + filebucket)

    # invoking the Vision API
    client = vision.ImageAnnotatorClient()
    response= json.loads(MessageToJson(client.annotate_image({
        'image': {'source': {'image_uri': 'gs://'+filebucket+'/'+filename}},
        'features': [
                    {'type_': vision.Feature.Type.LABEL_DETECTION},
                    {'type_': vision.Feature.Type.IMAGE_PROPERTIES},
                    {'type_': vision.Feature.Type.SAFE_SEARCH_DETECTION},
                ],
            })))
    print(response)
    if 'error' not in response:
        # listing the labels found in the picture
        labels = [ desc['description'] for desc in sorted(response['labelAnnotations'], key=lambda x: x['score'], reverse=True) ]
        print('Labels: ' + ", ".join(labels))

        # retrieving the dominant color of the picture
        color = sorted(response['imagePropertiesAnnotation']['dominantColors']['colors'], key=lambda x: x['score'], reverse=True)[0]['color']
        colorHex = decColorToHex((0 if 'red' not in color else int(color['red']), 0 if 'green' not in color else int(color['green']), 0 if 'blue' not in color else int(color['blue'])))
        print('Colors: ' + colorHex)

        # determining if the picture is safe to show
        safeSearch = response['safeSearchAnnotation']
        isSafe = True if list(dict((k, safeSearch[k]) for k in ["adult", "spoof", "medical", "violence", "racy"] if k in safeSearch).values()) not in ['LIKELY', 'VERY_LIKELY'] else False 
        print('Safe? ' + str(isSafe))

        # if the picture is safe to display, store it in Firestore
        if isSafe:
            pictureStore = store.collection(u'pictures')
            doc = pictureStore.document(filename)
            doc.set({
                    u'labels': labels,
                    u'color': colorHex,
                    u'created': datetime.datetime.now()
                    }, merge=True)

            print("Stored metadata in Firestore")
    else:
        print('Vision API error: code '+response['error']['code']+', message: "'+ response['error']['message'] +'"')