# =========================
# Stage 1: Build stage
# =========================
FROM ubuntu:22.04 AS builder

ARG DISK_FILE
ENV DISK_FILE=${DISK_FILE}
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt update && apt install -y --no-install-recommends \
    build-essential cmake clang lld \
    git curl unzip wget pkg-config \
    libssl-dev libcurl4-openssl-dev \
    protobuf-compiler libprotobuf-dev \
    libtss2-dev libtss2-tcti-device0 \
    ca-certificates software-properties-common python3-pip \
    efitools zip

RUN pip3 install pefile

RUN pip3 install google_crc32c

# Install Go 1.22.3
ENV GO_VERSION=1.22.3
RUN wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:$PATH"

# Set working directory
WORKDIR /app
COPY . .

RUN \
  ORIGINAL_EPOCH=$(stat -c %Y "$DISK_FILE") && \
  ./cvm-cli update-disk "$DISK_FILE" && \
  # if your update writes out to a new file, adjust path here:
  touch -d "@${ORIGINAL_EPOCH}" "$DISK_FILE" && \
  mkdir -p build && \
  mv "$DISK_FILE" build/