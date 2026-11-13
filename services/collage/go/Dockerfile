FROM golang:1.22-bookworm AS builder

RUN apt-get update && apt-get -q -y install --no-install-recommends libmagickwand-dev && rm -rf /var/lib/apt/lists/*

COPY go.* /app/
WORKDIR /app/
RUN go mod download
COPY . /app/
RUN go build -o main main.go

FROM debian:bookworm-slim

RUN apt-get update && apt-get -q -y install --no-install-recommends \
	ca-certificates \
	libmagickwand-6.q16-6 && \
	rm -rf /var/lib/apt/lists/* && \
	useradd -r -u 10001 -g nogroup appuser

COPY policy.xml /etc/ImageMagick-6/policy.xml
WORKDIR /app
COPY --from=builder /app/main /app/main

USER appuser
ENTRYPOINT ["/app/main"]
