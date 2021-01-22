// Copyright 2021 Google LLC
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

exports.vision_data_transform = (req, res) => {
    console.log(`Vision data: ${JSON.stringify(req.body)}`);

    const response = req.body.responses[0];
    console.log(`Response: ${JSON.stringify(response)}`);

    // listing the labels found in the picture
    const labels = response.labelAnnotations
        .sort((ann1, ann2) => ann2.score - ann1.score)
        .map(ann => {
            console.log(` - ${ann.description}`);
            return { stringValue: ann.description }
        })
    // console.log(`Labels: ${labels.join(', ')}`);

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

    res.json({
        safe: isSafe,
        labels: labels,
        color: colorHex,
        created: new Date()
    });
};

function decColorToHex(r, g, b) {
    return '#' + Number(r).toString(16).padStart(2, '0') +
                 Number(g).toString(16).padStart(2, '0') +
                 Number(b).toString(16).padStart(2, '0');
}