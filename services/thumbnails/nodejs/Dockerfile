# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM node:20-bookworm-slim

RUN set -ex; \
  apt-get -y update; \
  apt-get -y install --no-install-recommends imagemagick; \
  rm -rf /var/lib/apt/lists/*; \
  mkdir -p /tmp/original /tmp/thumbnail /picadaily/services/thumbnails; \
  chown -R node:node /tmp/original /tmp/thumbnail /picadaily

COPY policy.xml /etc/ImageMagick-6/policy.xml

WORKDIR /picadaily/services/thumbnails
COPY --chown=node:node package*.json ./
RUN npm install --omit=dev
COPY --chown=node:node . .

USER node
CMD [ "npm", "start" ]
