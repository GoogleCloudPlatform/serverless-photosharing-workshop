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
using System.Threading.Tasks;
using CloudNative.CloudEvents;
using Google.Cloud.Firestore;
using Google.Cloud.Storage.V1;
using Google.Events;
using Google.Events.Protobuf.Cloud.Audit.V1;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace GarbageCollector
{
    public class Startup
    {
        private const string EVENT_TYPE_AUDITLOG = "google.cloud.audit.log.v1.written";
        private string _bucketThumbnails;
        private string _projectId;

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

            var bucketImages = GetEnvironmentVariable("BUCKET_IMAGES");
            _bucketThumbnails = GetEnvironmentVariable("BUCKET_THUMBNAILS");
            _projectId = GetEnvironmentVariable("PROJECT_ID");

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapPost("/", async context =>
                {
                    var cloudEvent = await context.Request.ReadCloudEventAsync();
                    logger.LogInformation("Received CloudEvent\n" + GetEventLog(cloudEvent));

                    if (EVENT_TYPE_AUDITLOG != cloudEvent.Type)
                    {
                        logger.LogInformation($"Event type '{cloudEvent.Type}' is not {EVENT_TYPE_AUDITLOG}, ignoring.");
                        return;
                    }

                    //"protoPayload" : {"resourceName":"projects/_/buckets/events-atamel-images-input/objects/atamel.jpg}";
                    var logEntryData = CloudEventConverters.ConvertCloudEventData<LogEntryData>(cloudEvent);
                    var tokens = logEntryData.ProtoPayload.ResourceName.Split('/');
                    var bucket = tokens[3];
                    var objectName = tokens[5];

                    if (bucketImages != bucket)
                    {
                        logger.LogInformation($"Bucket '{bucket}' is not same as {bucketImages}, ignoring.");
                        return;
                    }

                    await DeleteFromThumbnailsAsync(objectName, logger);

                    await DeleteFromFirestore(objectName, logger);
                });
            });
        }

        private async Task DeleteFromFirestore(string objectName, ILogger logger)
        {
            var firestore = await FirestoreDb.CreateAsync(_projectId);
            var pictureStore = firestore.Collection("pictures");
            var docRef = pictureStore.Document(objectName);

            try
            {
                await docRef.DeleteAsync();
                logger.LogInformation($"Deleted '{objectName}' from Firestore collection 'pictures'");
            }
            catch (Exception e)
            {
                logger.LogInformation($"Failed to delete '{objectName}' from Firestore: {e.Message}.");
            }
        }

        private async Task DeleteFromThumbnailsAsync(string objectName, ILogger logger)
        {
            var client = await StorageClient.CreateAsync();
            try
            {
                await client.DeleteObjectAsync(_bucketThumbnails, objectName);
                logger.LogInformation($"Deleted '{objectName}' from bucket '{_bucketThumbnails}'.");
            }
            catch (Exception e)
            {
                logger.LogInformation($"Failed to delete '{objectName}' from bucket '{_bucketThumbnails}': {e.Message}.");
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

        private string GetEventLog(CloudEvent cloudEvent)
        {
            return $"ID: {cloudEvent.Id}\n"
                + $"Source: {cloudEvent.Source}\n"
                + $"Type: {cloudEvent.Type}\n"
                + $"Subject: {cloudEvent.Subject}\n"
                + $"DataSchema: {cloudEvent.DataSchema}\n"
                + $"DataContentType: {cloudEvent.DataContentType}\n"
                + $"Time: {cloudEvent.Time?.ToUniversalTime():yyyy-MM-dd'T'HH:mm:ss.fff'Z'}\n"
                + $"SpecVersion: {cloudEvent.SpecVersion}\n"
                + $"Data: {cloudEvent.Data}";
        }
    }
}
