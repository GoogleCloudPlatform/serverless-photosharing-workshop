FROM debian:11-slim
RUN apt-get update && apt-get install -y openjdk-17-jdk openjdk-17-jre libmagickwand-dev imagemagick jmagick

ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
ENTRYPOINT ["java", "-Djmagick.systemclassloader=no", "-jar","/app.jar"]