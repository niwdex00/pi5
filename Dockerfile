# Stage 1: Build Stage (Ubuntu with dependencies)
FROM ubuntu:22.04 AS build

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
    python3 \
    python3-pip \
    gcc-aarch64-linux-gnu \
    make \
    crossbuild-essential-arm64 \
    u-boot-tools

# Install Go and other dependencies
ENV GO_VERSION=1.23.3
RUN wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin


# Stage 2: DIND (Docker-in-Docker)
FROM docker:rc-dind

# Copy necessary binaries, libraries, and Go installation from the build stage
COPY --from=build /usr/local /usr/local
COPY --from=build /usr/bin /usr/bin
COPY --from=build /usr/lib /usr/lib
COPY --from=build /usr/include /usr/include

# Set the Go binary path
ENV PATH=$PATH:/usr/local/go/bin
ENV PATH=$PATH:/usr/bin

# Install git
RUN apk add git && \
	ls -l /usr/bin/git && \
	chmod +x /usr/bin/git && \
	PATH="/usr/bin:$PATH" && \
	ldd /usr/bin/git
	

# Clone the Talos repository and Raspberry Pi Linux kernel repository
WORKDIR /workspace
RUN git clone --single-branch https://github.com/siderolabs/talos.git && \
    git clone --depth=1 https://github.com/raspberrypi/linux.git

# Kernel build step
WORKDIR /workspace/linux
RUN ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make bcm2711_defconfig

# Copy kernel config to Talos kernel build directory
RUN cp /workspace/linux/.config /workspace/talos/pkg/kernel/.config

# Set working directory to Talos
WORKDIR /workspace/talos

# Install Go dependencies
RUN go mod tidy && \
    go mod download

# Build the Talos image for arm64
RUN make image-arm64

# Copy the final output to /output
RUN mkdir -p /output && cp build/talos/*.xz /output/
