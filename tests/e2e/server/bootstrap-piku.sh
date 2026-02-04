#!/bin/bash
set -e

sleep 5

mkdir -p /root/.ssh
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
cat /root/.ssh/id_ed25519.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

cd /root
./piku-bootstrap first-run --no-interactive

EXTRA_VARS=""
if [ -n "$PIKU_REPO" ]; then
    EXTRA_VARS="--piku-repo=$PIKU_REPO"
fi
if [ -n "$PIKU_BRANCH" ]; then
    EXTRA_VARS="$EXTRA_VARS --piku-branch=$PIKU_BRANCH"
fi

./piku-bootstrap install $EXTRA_VARS

mkdir -p /shared-keys
cp /root/.ssh/id_ed25519 /shared-keys/
cp /root/.ssh/id_ed25519.pub /shared-keys/

cat /root/.ssh/id_ed25519.pub | sudo -u piku tee -a /home/piku/.ssh/authorized_keys > /dev/null

touch /root/.piku-bootstrap-complete
echo "=== Piku bootstrap complete ==="
