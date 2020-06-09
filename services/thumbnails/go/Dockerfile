FROM golang:1.11-buster AS builder

# Install ImageMagick dev library
RUN apt-get update && apt-get -q -y install libmagickwand-dev

ADD go.* /app/
WORKDIR /app/
RUN go mod download
ADD . /app/
RUN go build -o main main.go

# final stage
FROM debian:buster-slim

# Install ImageMagick deps and ca-certificates
RUN apt-get update && apt-get -q -y install \
	ca-certificates \
	libmagickwand-6.q16-6 && \
	rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/main ./

ENTRYPOINT ["./main"]
