#!/usr/bin/env bash
#These function will create the passwords to their corresponding elements (Be sure to rename these.)
printf '%s' 'changeRoot!' > mysql_root_password.txt
printf '%s' 'changeApp!' > app_db_password.txt
printf '%s' 'changeRouter!' > router_bootstrap_password.txt
printf '%s' 'changeClusterAdmin!' > cluster_admin_password.txt
printf '%s' 'firefly_user' > app_db_user.txt
#Save a copy of your GCP service key json. (Be sure to add the path to it)
cp /path/to/your-gcp-sa-key.json gcp-sa-key.json

#Creates the secrets for the Docker Swarm
docker secret create mysql_root_password mysql_root_password.txt
docker secret create app_db_password app_db_password.txt
docker secret create router_bootstrap_password router_bootstrap_password.txt
docker secret create cluster_admin_password cluster_admin_password.txt
docker secret create app_db_user app_db_user.txt
docker secret create gcp_sa_key gcp_sa_key.json
