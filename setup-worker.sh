#!/bin/bash
#Run on each swarm worker

set -e

echo "Running LVM setup..."
sudo bash ./lvm-setup.sh

echo "Installing Docker if not present..."
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | sudo bash
fi

echo "Join the Swarm by pasting the join command below:"
echo ""
echo "    docker swarm join --token <token> <manager-ip>:2377"
echo ""
echo "DONE - Worker setup done."
