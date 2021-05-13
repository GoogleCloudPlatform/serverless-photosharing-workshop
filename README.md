# Pic-a-daily

## Introduction

This is the code for the Pic-a-daily, an application to upload, analyse and
share pictures using Google Cloud serverless solutions, namely Cloud Functions,
App Engine, and Cloud Run.

There are 2 versions of the app:

1. Choreographed version using events from Cloud Functions, Pub/Sub, Eventarc.
2. Orchestrated version using Workflows.

## Labs

There is a workshop you can follow to build the app:

* [Lab 1 — Store and analyse pictures](https://codelabs.developers.google.com/codelabs/cloud-picadaily-lab1)
* [Lab 2 — Create thumbnails of big pictures](https://codelabs.developers.google.com/codelabs/cloud-picadaily-lab2)
* [Lab 3 — Run containers on a schedule](https://codelabs.developers.google.com/codelabs/cloud-picadaily-lab3)
* [Lab 4 — Create a web frontend](https://codelabs.developers.google.com/codelabs/cloud-picadaily-lab4)
* [Lab 5 — Image garbage collector](https://codelabs.developers.google.com/codelabs/cloud-picadaily-lab5)
* [Lab 6 — Orchestration with Workflows](https://codelabs.developers.google.com/codelabs/cloud-picadaily-lab6)

## Presentation

There's a [presentation](https://speakerdeck.com/meteatamel/pic-a-daily-serverless-workshop) that accompanies the workshop.

<a href="https://speakerdeck.com/meteatamel/pic-a-daily-serverless-workshop">
    <img alt="Pic-a-Daily Serverless Workshop" src="pic-a-daily-presentation.png" width="50%" height="50%">
</a>

## Architecture - Choreographed (event-driven)

<img alt="Pic-a-daily Architecture - Choreographed" src="pic-a-daily-architecture-events.png" width="50%" height="50%">

## Architecture - Orchestrated

<img alt="Pic-a-daily Architecture - Orchestrated" src="pic-a-daily-architecture-workflows.png" width="50%" height="50%">

## Scripts and Terraform

There are shell [scripts](scripts) and [terraform](terraform) configs to setup each lab.

## Solutions used

The app uses the following solutions:

Compute:

* [Cloud Functions](https://cloud.google.com/functions/) — functions as a service
* [App Engine](https://cloud.google.com/appengine/) — application as a service
* [Cloud Run](https://cloud.google.com/run/) — container as a service

Data:

* [Cloud Storage](https://cloud.google.com/storage/) — for storing file blobs (images)
* [Cloud Firestore](https://cloud.google.com/firestore/) — for structured data

Services:

* [Eventarc](https://cloud.google.com/run/docs/quickstarts/events) - to receive events from various Google Cloud sources.
* [Vision API](https://cloud.google.com/vision/) — to analyze pictures
* [Cloud Logging](https://cloud.google.com/logging/) — to track interesting events
* [Cloud Scheduler](https://cloud.google.com/scheduler/) — to run workloads on a schedule
* [Cloud Pub/Sub](https://cloud.google.com/pubsub) — for publish/subscribe-type messaging
* [Cloud Shell](https://cloud.google.com/shell) — for developing online, in the cloud
* [Workflows](https://cloud.google.com/workflows) - to orchestrate services

-------

This is not an official Google product.
