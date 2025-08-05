#!/bin/bash
#run on the manager node

set -e

echo "Running LVM setup..."
sudo bash ./lvm-setup.sh

echo "Sourcing secrets..."
source ./secrets.sh

echo "Initializing Docker Swarm (ignore if already initialized)..."
docker swarm init || true

echo "Deploying stack using docker-compose.yaml..."
docker stack deploy -c docker-compose.yaml firefly_stack

echo "Waiting for services to stabilize..."
sleep 30

echo "Bootstrapping MySQL Group Replication..."
docker exec -i $(docker ps --filter name=firefly_mysql -q) mysqlsh < cluster-init.js

echo "DONE - Deployment complete. Firefly should be accessible at http://<manager-ip>:80"
