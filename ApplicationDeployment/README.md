# Firefly III Application Deployment

This project deploys a highly available Firefly III personal finance manager using Docker Swarm.

## Deployment Steps:
1. Initialize Docker Swarm:
   ```bash
   docker swarm init
   docker stack deploy -c docker-compose.yml firefly_stack
   docker service scale firefly_stack_firefly=6
