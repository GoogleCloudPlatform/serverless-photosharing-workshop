FROM debian:12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends openjdk-17-jre-headless libmagickwand-6.q16-6 imagemagick jmagick && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -r -u 10001 -g nogroup appuser

COPY policy.xml /etc/ImageMagick-6/policy.xml

ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} /app/app.jar

USER appuser
ENTRYPOINT ["java", "-Djmagick.systemclassloader=no", "-jar", "/app/app.jar"]
