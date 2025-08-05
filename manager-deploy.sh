#!/bin/bash
# run on the manager node

set -e

echo "Running LVM setup..."
sudo bash ./fullDeploy/lvm-setup.sh

echo "Sourcing secrets..."
source ./fullDeploy/secrets.sh

echo "Initializing Docker Swarm (ignore if already initialized)..."
docker swarm init || true

echo "Deploying stack using docker-compose.yaml..."
docker stack deploy -c ./fullDeploy/docker-compose.yaml firefly_stack

echo "Waiting for MySQL container to start..."
sleep 10

MYSQL_CID=$(docker ps --filter name=firefly_mysql -q | head -n1)
if [ -z "$MYSQL_CID" ]; then
  echo "ERROR: MySQL container not running or named incorrectly. Aborting bootstrap."
  exit 1
fi

echo "Waiting for MySQL container to be healthy..."
while ! docker inspect --format='{{.State.Health.Status}}' "$MYSQL_CID" 2>/dev/null | grep -q healthy; do
  sleep 5
  echo "Still waiting..."
done

echo "Bootstrapping MySQL Group Replication..."
docker exec -i "$MYSQL_CID" mysqlsh < cluster-init.js

echo "DONE - Deployment complete. Firefly should be accessible at http://<manager-ip>:80"
