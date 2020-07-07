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
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Google.Cloud.Firestore;
using Google.Cloud.Storage.V1;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;

namespace QueryRunner
{
    public class Startup
    {
        public void ConfigureServices(IServiceCollection services)
        {
        }

        public void Configure(IApplicationBuilder app, IWebHostEnvironment env, ILogger<Startup> logger)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            logger.LogInformation("Service is starting...");

            app.UseRouting();

            var thumbBucket = GetEnvironmentVariable("BUCKET_THUMBNAILS");
            var projectId = GetEnvironmentVariable("PROJECT_ID");

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapPost("/", async context =>
                {
                    var pictureNames = await GetPictureNames(projectId);
                    if (pictureNames.Count == 0)
                    {
                        logger.LogInformation("Empty collection, no collage to make");
                        context.Response.StatusCode = 204;
                        return;
                    }
                    logger.LogInformation("Picture file names: " + string.Join(", ", pictureNames));

                    var inputStreams = new List<MemoryStream>();
                    var client = await StorageClient.CreateAsync();

                    foreach (var name in pictureNames)
                    {
                        var inputStream = new MemoryStream();
                        await client.DownloadObjectAsync(thumbBucket, name, inputStream);
                        logger.LogInformation($"Downloaded '{name}'...");
                        inputStreams.Add(inputStream);
                    }
                    logger.LogInformation("Downloaded all thumbnails");


                    await CreateCollage(inputStreams, thumbBucket, logger);
                    logger.LogInformation($"Uploaded 'collage.png' to bucket '{thumbBucket}'");
                });
            });
        }

        private async Task<List<string>> GetPictureNames(string projectId)
        {
            var firestore = await FirestoreDb.CreateAsync(projectId);
            var pictureStore = firestore.Collection("pictures");

            var query = pictureStore
                .WhereEqualTo("thumbnail", true)
                .OrderByDescending("created")
                .Limit(4);
            var snapshot = await query.GetSnapshotAsync();

            var pictureNames = from document in snapshot.Documents
                               select document.Id;

            return pictureNames.ToList();
        }

        private async Task CreateCollage(List<MemoryStream> memoryStreams, string bucket, ILogger logger)
        {
            memoryStreams.ForEach(memoryStream => memoryStream.Position = 0);
            using (var img0 = Image.Load(memoryStreams[0]))
            using (var img1 = Image.Load(memoryStreams[1]))
            using (var img2 = Image.Load(memoryStreams[2]))
            using (var img3 = Image.Load(memoryStreams[3]))
            using (var outputStream = new MemoryStream())
            using (var outputImage = new Image<Rgba32>(800, 800))
            {
                outputImage.Mutate(o => o
                    .DrawImage(img0, new Point(0, 0), 1f)
                    .DrawImage(img1, new Point(400, 0), 1f)
                    .DrawImage(img2, new Point(0, 400), 1f)
                    .DrawImage(img3, new Point(400, 400), 1f)
                );
                outputImage.SaveAsPng(outputStream);
                logger.LogInformation("Created local collage picture");

                var client = await StorageClient.CreateAsync();
                await client.UploadObjectAsync(bucket, "collage.png", "image/png", outputStream);
            }
        }

        private string GetEnvironmentVariable(string var)
        {
            var value = Environment.GetEnvironmentVariable(var);
            if (string.IsNullOrEmpty(value))
            {
                throw new ArgumentNullException(var);
            }
            return value;
        }
    }
}
