// Copyright 2020, Google LLC
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
using CloudNative.CloudEvents;
using Google.Cloud.Functions.Framework;
using Google.Cloud.Vision.V1;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using static Google.Cloud.Vision.V1.Feature.Types.Type;
using Google.Cloud.Firestore;
using Google.Events.Protobuf.Cloud.Storage.V1;

namespace ImageAnalysis
{
    /// <summary>
    /// Function to watch for new image files being added to a storage bucket,
    /// use the Google Cloud Vision API to determine if it's a safe image.
    //  If so, extract labels and dominant colors to save to Firestore.
    /// </summary>
    public class Function : ICloudEventFunction<StorageObjectData>
    {
        private readonly FirestoreDb _firestoreDb;

        private readonly ImageAnnotatorClient _visionClient;
        private readonly ILogger _logger;

        /// <summary>
        ///  Constructor accepting all our dependencies. The clients are configured in
        ///  Startup.cs.
        /// </summary>
        public Function(ImageAnnotatorClient visionClient, FirestoreDb firestoreDb, ILogger<Function> logger) =>
            (_visionClient, _firestoreDb, _logger) = (visionClient, firestoreDb, logger);

        /// <summary>
        /// Entry point for the function. This is called whenever a new storage file is created.
        /// </summary>
        /// <param name="payload">The storage object that's been uploaded.</param>
        /// <param name="context">Event context (event ID etc)</param>
        public async Task HandleAsync(CloudEvent cloudEvent, StorageObjectData data, CancellationToken cancellationToken)
        {
            _logger.LogInformation($"New picture uploaded {data.Name} in {data.Bucket}");

            var annotations = await AnnotateImageAsync(data, cancellationToken);
            await ProcessAnnotations(data.Name, annotations);
        }

        /// <summary>
        /// Use the Vision API to annotate the image.
        /// </summary>
        private Task<AnnotateImageResponse> AnnotateImageAsync(StorageObjectData data, CancellationToken cancellationToken)
        {
            var features = new[] { LabelDetection, Feature.Types.Type.ImageProperties, SafeSearchDetection}
                .Select(type => new Feature { Type = type, MaxResults = 20 });
            var request = new AnnotateImageRequest
            {
                Image = Image.FromUri($"gs://{data.Bucket}/{data.Name}"),
                Features = { features }
            };
            return _visionClient.AnnotateAsync(request, cancellationToken);
        }

        /// <summary>
        /// Determin whether the image is safe, extract labels, dominant colors
        /// and save to Firestore.
        /// </summary>
        private async Task ProcessAnnotations(string filename, AnnotateImageResponse response)
        {
            var labels = response.LabelAnnotations
                .OrderBy(annotation => annotation.Score)
                .Select(annotation => annotation.Description);
            _logger.LogInformation($"Labels: {string.Join(",", labels)}");

            var color = response.ImagePropertiesAnnotation.DominantColors.Colors
                .OrderByDescending(c => c.Score)
                .Select(c => c.Color)
                .First();

            var colorHex = $"#{((int)color.Red):X2}{((int)color.Green):X2}{((int)color.Blue):X2}";
            _logger.LogInformation($"Colors: {colorHex}");

            var safeSearch = response.SafeSearchAnnotation;
            var isSafe = safeSearch.Adult < Likelihood.Possible
                && safeSearch.Medical < Likelihood.Possible
                && safeSearch.Racy < Likelihood.Possible
                && safeSearch.Spoof < Likelihood.Possible
                && safeSearch.Violence < Likelihood.Possible;
            _logger.LogInformation($"Safe? {isSafe}");

            if (isSafe)
            {
                var pictureStore = _firestoreDb.Collection("pictures");

                var doc = pictureStore.Document(filename);
                var metadata = new Dictionary<string, object>()
                {
                    {"labels", labels.ToList()},
                    {"color", colorHex},
                    {"created", Timestamp.GetCurrentTimestamp()}
                };
                await doc.SetAsync(metadata, SetOptions.MergeAll);

                 _logger.LogInformation("Stored metadata in Firestore");
            }

        }
    }
}