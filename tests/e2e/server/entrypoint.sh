#!/bin/bash
# Write runtime environment variables for the bootstrap script
echo "PIKU_REPO=${PIKU_REPO:-piku/piku}" > /tmp/piku-env
echo "PIKU_BRANCH=${PIKU_BRANCH:-master}" >> /tmp/piku-env
echo "Environment written to /tmp/piku-env:"
cat /tmp/piku-env

# Start systemd
exec /lib/systemd/systemd
