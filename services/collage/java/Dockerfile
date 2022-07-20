FROM debian:11-slim
# FROM adoptopenjdk:11-jre-hotspot

# FROM maven:3-openjdk-17-slim
RUN apt-get update && apt-get install -y openjdk-17-jdk openjdk-17-jre libmagickwand-dev imagemagick jmagick
# RUN apt-get update && apt-get update && apt-get install -y libmagickwand-dev imagemagick jmagick

ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
ENTRYPOINT ["java", "-Djmagick.systemclassloader=no", "-jar","/app.jar"]