# Firefly III Docker Swarm Deployment

A production-ready Docker Swarm deployment of [Firefly III](https://www.firefly-iii.org/) - a self-hosted personal finance manager.

## Overview

This deployment includes:
- **Firefly III** - Personal finance management application
- **MySQL** - Database backend
- **Nginx** - Reverse proxy with load balancing
- **Docker Swarm** - Orchestration with automatic scaling and healing

## Prerequisites

- Ubuntu 25.02 (or compatible Linux distribution)
- Docker Engine with Swarm mode initialized
- Basic understanding of Docker and terminal commands

## Project Structure

```
firefly-deployment/
├── docker-compose.yaml     # Main deployment configuration
├── nginx/
│   └── nginx.conf         # Nginx reverse proxy configuration
├── mysql_root_password.txt # MySQL root password (keep secure!)
├── db_user_password.txt    # Database user password (keep secure!)
├── deploy-firefly.sh      # Deployment script
└── README.md              # This file
```

## Quick Start

1. **Initialize Docker Swarm** (if not already done):
   ```bash
   docker swarm init
   ```

2. **Clone or create the project directory**:
   ```bash
   mkdir -p DatabaseContainerDeployment/nginx
   cd DatabaseContainerDeployment
   ```

3. **Password files**:
   ```The password files are provided with the directory```

4. **Create configuration files**:
   - Copy the `docker-compose.yaml` from this repository
   - Copy the `nginx.conf` to `nginx/nginx.conf`

5. **Deploy Firefly III**:
   ```sudo docker stack deploy -c docker-compose.yaml firefly```

6. **Insert the MySQL table**:
  ```Run the following commands to resolve the Firefly no database error```
   - FIREFLY_CONTAINER=$(sudo docker ps --filter "label=com.docker.swarm.service.name=firefly_firefly" -q | head -1)
   - sudo docker exec -it $FIREFLY_CONTAINER php artisan cache:table
   - sudo docker exec -it $FIREFLY_CONTAINER php artisan session:table

7. **Access Firefly III**:
   - Open your browser to `http://(External IP):80`
   - Complete the registration process

## Configuration

### Environment Variables

The deployment requires an `APP_KEY` environment variable. The deployment script generates this automatically, but you should save it for future deployments:

```bash
# View your APP_KEY
echo $APP_KEY

# Set it for future sessions
export APP_KEY="your-saved-app-key"
```

### Key Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_KEY` | Laravel application key (required) | Provided in yaml |
| `SESSION_DRIVER` | Session storage method | `file` |
| `CACHE_DRIVER` | Cache storage method | `array` |
| `TRUSTED_PROXIES` | Proxy configuration | `**` |
| `APP_URL` | Application URL | `http://localhost` |

## Database Management

### Check Database Status

```bash
# Quick database check
./check_db.sh

# Manual database connection
MYSQL_CONTAINER=$(docker ps --filter "label=com.docker.swarm.service.name=firefly_mysql" -q)
docker exec -it $MYSQL_CONTAINER mysql -u firefly -p$(cat db_user_password.txt) firefly
```

### Backup Database

```bash
# Create backup
MYSQL_CONTAINER=$(docker ps --filter "label=com.docker.swarm.service.name=firefly_mysql" -q)
docker exec $MYSQL_CONTAINER mysqldump -u firefly -p$(cat db_user_password.txt) firefly > firefly_backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restore Database

```bash
# Restore from backup
MYSQL_CONTAINER=$(docker ps --filter "label=com.docker.swarm.service.name=firefly_mysql" -q)
docker exec -i $MYSQL_CONTAINER mysql -u firefly -p$(cat db_user_password.txt) firefly < firefly_backup.sql
```

## Monitoring

### View Service Status

```bash
# All services
docker service ls

# Specific service details
docker service ps firefly_firefly
docker service ps firefly_mysql
docker service ps firefly_nginx

# View logs
docker service logs firefly_firefly --follow
docker service logs firefly_mysql --tail 50
```

### Health Checks

The deployment includes health checks for automatic recovery:
- **MySQL**: Checks database connectivity
- **Firefly**: Checks API endpoint availability

## Troubleshooting

### 419 Page Expired Error

This occurs when session management fails. Solutions:
1. Clear browser cookies and cache
2. Ensure `APP_KEY` is set correctly
3. Check if using multiple replicas without proper session handling

### 500 Internal Server Error

Usually database-related:
1. Check MySQL is running: `docker service ps firefly_mysql`
2. Verify database migrations: 
   ```bash
   FIREFLY_CONTAINER=$(docker ps --filter "label=com.docker.swarm.service.name=firefly_firefly" -q | head -1)
   docker exec $FIREFLY_CONTAINER php artisan migrate --force
   ```

### Container Restart Loops

Check logs for specific errors:
```bash
docker service logs firefly_firefly --tail 100
```

## Maintenance

### Update Firefly III

```bash
# Pull latest image
docker pull fireflyiii/core:latest

# Update service
docker service update --image fireflyiii/core:latest firefly_firefly
```

### Clean Up Old Data

```bash
# Remove unused Docker resources
docker system prune -a

# Clean application cache
FIREFLY_CONTAINER=$(docker ps --filter "label=com.docker.swarm.service.name=firefly_firefly" -q | head -1)
docker exec $FIREFLY_CONTAINER php artisan cache:clear
```

## Security Considerations

1. **Password Files**: 
   - Keep `mysql_root_password.txt` and `db_user_password.txt` secure
   - Never commit these to version control
   - Use strong, randomly generated passwords

2. **Network Security**:
   - The deployment uses an overlay network for service isolation
   - Only Nginx port 80 is exposed externally
   - Consider adding HTTPS with proper certificates for production

3. **Backups**:
   - Regularly backup the MySQL database
   - Store backups securely and test restoration procedures

4. **Updates**:
   - Keep all images updated with security patches
   - Monitor Firefly III releases for security updates

## Advanced Configuration

### Enable HTTPS

1. Update `nginx.conf` to include SSL configuration
2. Mount SSL certificates as configs or secrets
3. Update port mapping in `docker-compose.yaml`

### Use External Database

Modify the `docker-compose.yaml` to point to an external MySQL/MariaDB instance:
```yaml
environment:
  DB_HOST: your-external-db-host
  DB_PORT: 3306
  DB_DATABASE: firefly
  DB_USERNAME: firefly
  DB_PASSWORD: your-password
```

### Add Redis for Better Performance

See the Redis configuration example in the deployment files for session and cache management with multiple replicas.

## Support and Resources

- **Firefly III Documentation**: https://docs.firefly-iii.org/
- **Firefly III GitHub**: https://github.com/firefly-iii/firefly-iii
- **Docker Swarm Documentation**: https://docs.docker.com/engine/swarm/
- **Issues**: Check service logs and Firefly III documentation

## License

This deployment configuration is provided as-is. Firefly III is licensed under the AGPL-3.0 License.