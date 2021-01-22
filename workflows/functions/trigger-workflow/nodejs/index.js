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

const {ExecutionsClient} = require('@google-cloud/workflows');
const client = new ExecutionsClient();

const GOOGLE_CLOUD_PROJECT = process.env.GOOGLE_CLOUD_PROJECT;
const WORKFLOW_REGION = process.env.WORKFLOW_REGION;
const WORKFLOW_NAME = process.env.WORKFLOW_NAME;

exports.trigger_workflow = async (event, context) => {
  console.log(`GCS event: ${JSON.stringify(event)}`);

  const file = event.name;
  const bucket = event.bucket;

  console.log(`New picture received: ${file}, from bucket: ${bucket}`);

  try {
    const execResponse = await client.createExecution({
      parent: client.workflowPath(GOOGLE_CLOUD_PROJECT, WORKFLOW_REGION, WORKFLOW_NAME),
      execution: {
        argument: JSON.stringify({file, bucket, eventType: "OBJECT_FINALIZE"})
      }
    });
    console.log(`Execution response: ${JSON.stringify(execResponse)}`);

    const execName = execResponse[0].name;
    console.log(`Created execution: ${execName}`);

  } catch (e) {
    console.error(`Error executing workflow: ${e}`);
    throw e;
  }
};