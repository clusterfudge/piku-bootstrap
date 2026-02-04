#!/bin/bash
set -e

echo "=== Starting piku bootstrap ==="
date

# Wait for systemd to be fully ready
sleep 10

# Set up SSH keys for root
echo "Setting up SSH keys..."
mkdir -p /root/.ssh
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
cat /root/.ssh/id_ed25519.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Run piku-bootstrap
cd /root
echo "Running piku-bootstrap first-run..."
./piku-bootstrap first-run --no-interactive

# Read env vars from file if it exists (created by docker-compose)
if [ -f /tmp/piku-env ]; then
    source /tmp/piku-env
fi

# Build extra vars for piku-bootstrap
EXTRA_VARS=""
if [ -n "$PIKU_REPO" ]; then
    echo "Using piku repo: $PIKU_REPO"
    EXTRA_VARS="--piku-repo=$PIKU_REPO"
fi
if [ -n "$PIKU_BRANCH" ]; then
    echo "Using piku branch: $PIKU_BRANCH"
    EXTRA_VARS="$EXTRA_VARS --piku-branch=$PIKU_BRANCH"
fi

echo "Running piku-bootstrap install $EXTRA_VARS..."
./piku-bootstrap install $EXTRA_VARS

# Wait for shared-keys volume to be available and copy keys
echo "Copying SSH keys to shared volume..."
for i in $(seq 1 30); do
    if [ -d /shared-keys ]; then
        cp /root/.ssh/id_ed25519 /shared-keys/
        cp /root/.ssh/id_ed25519.pub /shared-keys/
        chmod 644 /shared-keys/id_ed25519.pub
        chmod 600 /shared-keys/id_ed25519
        echo "SSH keys copied to shared volume"
        break
    fi
    echo "Waiting for shared-keys volume... ($i/30)"
    sleep 2
done

# Add SSH key to piku user's authorized_keys
echo "Adding SSH key to piku user..."
cat /root/.ssh/id_ed25519.pub | sudo -u piku tee -a /home/piku/.ssh/authorized_keys > /dev/null

# Signal completion
touch /root/.piku-bootstrap-complete
echo "=== Piku bootstrap complete ==="
date
