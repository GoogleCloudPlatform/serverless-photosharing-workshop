FROM node:10-slim

# installing Imagemagick
RUN set -ex; \
  apt-get -y update; \
  apt-get -y install imagemagick; \
  rm -rf /var/lib/apt/lists/*

WORKDIR /picadaily/services/collage
COPY package*.json ./
RUN npm install --production
COPY . .
CMD [ "npm", "start" ]