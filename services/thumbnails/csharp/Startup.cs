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
using System.IO;
using System.Text;
using Google.Cloud.Storage.V1;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;

namespace QueryRunner
{
    public class Startup
    {
        private const int ThumbWidth = 400;
        private const int ThumbHeight = 400;

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

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapPost("/", async context =>
                {
                    JToken pubSubMessage;
                    using (var reader = new StreamReader(context.Request.Body))
                    {
                        pubSubMessage = JValue.Parse(await reader.ReadToEndAsync());
                        logger.LogInformation("PubSub message: " + pubSubMessage);
                    }

                    var data = (string)pubSubMessage["message"]["data"];
                    var fileEvent = JValue.Parse(Encoding.UTF8.GetString(Convert.FromBase64String(data)));
                    logger.LogInformation("Base 64 decoded file event: " + fileEvent);

                    var bucket = (string)fileEvent["bucket"];
                    var name = (string)fileEvent["name"];

                    using (var inputStream = new MemoryStream())
                    {
                        var client = await StorageClient.CreateAsync();
                        await client.DownloadObjectAsync(bucket, name, inputStream);
                        logger.LogInformation($"Downloaded '{name}' from bucket '{bucket}'");

                        using (var outputStream = new MemoryStream())
                        {
                            inputStream.Position = 0; // Reset to read
                            using (Image image = Image.Load(inputStream))
                            {
                                image.Mutate(x => x
                                    .Resize(ThumbWidth, ThumbHeight)
                                );
                                logger.LogInformation($"Resized image '{name}' to {ThumbWidth}x{ThumbHeight}");

                                image.SaveAsPng(outputStream);
                            }

                            await client.UploadObjectAsync(thumbBucket, name, "image/png", outputStream);
                            logger.LogInformation($"Uploaded '{name}' to bucket '{thumbBucket}'");
                        }
                    }

                });
            });
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
