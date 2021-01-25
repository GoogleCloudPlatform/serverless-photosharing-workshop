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

const THUMBNAILS_URL = process.env.THUMBNAILS_URL;
const COLLAGE_URL = process.env.COLLAGE_URL;
const GARBAGE_COLLECTOR_URL = process.env.GARBAGE_COLLECTOR_URL;
const VISION_DATA_TRANSFORM_URL = process.env.VISION_DATA_TRANSFORM_URL;
const urls = {THUMBNAILS_URL, COLLAGE_URL, GARBAGE_COLLECTOR_URL, VISION_DATA_TRANSFORM_URL};

exports.trigger_workflow = async (event, context) => {
  console.log(`GCS event: ${JSON.stringify(event)}`);

  console.log(`URLs: ${JSON.stringify(urls)}`);

  const file = event.name;
  const bucket = event.bucket;

  const eventType = context.eventType;
  console.log(`Event type: ${eventType}`);

  if (eventType == 'google.storage.object.finalize') {
    console.log(`New picture received: ${file}, from bucket: ${bucket}`);
  } else if (eventType == 'google.storage.object.delete') {
    console.log(`Request to delete: ${file}, from bucket: ${bucket}`);
  } else {
    console.log(`Unrecognized event type: ${eventType}`);
    return;
  }

  try {
    console.log(`workflow path: ${GOOGLE_CLOUD_PROJECT}, ${WORKFLOW_REGION}, ${WORKFLOW_NAME}`);
    const execResponse = await client.createExecution({
      parent: client.workflowPath(GOOGLE_CLOUD_PROJECT, WORKFLOW_REGION, WORKFLOW_NAME),
      execution: {
        argument: JSON.stringify({file, bucket, eventType, urls})
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