# Use a base image with Ubuntu for build environment
FROM ubuntu:22.04

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    bc \
    bison \
    flex \
    libssl-dev \
    libncurses5-dev \
    libelf-dev \
    git \
    wget \
    gcc-aarch64-linux-gnu \
    make \
    crossbuild-essential-arm64 \
    u-boot-tools \
    python3 \
    python3-pip

# Install Go and other dependencies
RUN wget https://dl.google.com/go/go1.19.9.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.19.9.linux-amd64.tar.gz && \
    rm go1.19.9.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

# Clone the Talos repository
WORKDIR /workspace
RUN git clone --single-branch https://github.com/siderolabs/talos.git

# Set working directory to Talos kernel build directory
WORKDIR /workspace/talos

# Install dependencies using Go tools
RUN go mod download

# Copy kernel config
COPY kernel.config /workspace/talos/pkg/kernel/.config

# Build the Talos image
RUN make image-arm64

# Copy the final output to /output
WORKDIR /workspace/talos/build/talos
RUN mkdir -p /output && cp *.xz /output/
