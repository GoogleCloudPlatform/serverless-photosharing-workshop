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
using Google.Cloud.Firestore;
using Google.Cloud.Vision.V1;
using ImageAnalysis;
using Microsoft.Extensions.DependencyInjection;
using System;
using Google.Cloud.Functions.Hosting;
using Microsoft.AspNetCore.Hosting;

[assembly: FunctionsStartup(typeof(Startup))]

namespace ImageAnalysis
{
    /// <summary>
    /// Startup class to provide the Storage and Vision API clients via dependency injection.
    /// We use singleton instances as the clients are thread-safe, and this ensures
    /// an efficient use of connections.
    /// </summary>
    public class Startup : FunctionsStartup
    {
        //public override void Configure(IFunctionsHostBuilder builder)
        public override void ConfigureServices(WebHostBuilderContext context, IServiceCollection services)
        {
            services.AddSingleton(ImageAnnotatorClient.Create());
            var projectId = GetEnvironmentVariable("PROJECT_ID");
            services.AddSingleton(FirestoreDb.Create(projectId));
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
