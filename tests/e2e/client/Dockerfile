# Test Client Dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    curl \
    git \
    openssh-client \
    jq \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

WORKDIR /tests

# Use shell form to avoid exec issues
CMD bash -c "while true; do sleep 1000; done"
