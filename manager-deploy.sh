#!/bin/bash
# run on the manager node

set -e

echo "Running LVM setup..."
sudo bash ./fullDeploy/lvm-setup.sh

echo "Checking for Docker..."
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found. Installing..."
  curl -fsSL https://get.docker.com | sudo bash
fi

echo "Initializing Docker Swarm (ignore if already initialized)..."
docker swarm init || true

echo "Deploying stack using docker-compose.yaml..."
docker stack deploy -c ./fullDeploy/docker-compose.yaml firefly_stack

echo "Waiting for MySQL container to start..."
sleep 10

MYSQL_CID=$(docker ps --filter name=firefly_stack_mysql -q | head -n1)
if [ -z "$MYSQL_CID" ]; then
  echo "ERROR: MySQL container not running or named incorrectly. Aborting bootstrap."
  exit 1
fi

echo "Waiting for MySQL container to be healthy..."
while ! docker inspect --format='{{.State.Health.Status}}' "$MYSQL_CID" 2>/dev/null | grep -q healthy; do
  sleep 5
  echo "Still waiting..."
done

FIREFLY_CONTAINER=$(docker ps --filter name=firefly_stack_firefly -q | head -n1)
echo "Setting up MySQL tables..."
sudo docker exec -it $FIREFLY_CONTAINER php artisan migrate --force
sudo docker exec -it $FIREFLY_CONTAINER php artisan cache:table
sudo docker exec -it $FIREFLY_CONTAINER php artisan session:table

echo "DONE - Deployment complete. Firefly should be accessible at http://<manager-ip>:80"
