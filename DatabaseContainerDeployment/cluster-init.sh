#!/usr/bin/env/ bash
#Initialized the One-shot cluster boostrap for automation

set -euo pipefail

ROOT_PW="$(cat /run/secrets/mysql_root_password)"
CLUSTER_ADMIN_PW="$(cat /run/secrets/cluster_admin_password)"
APP_USER="$(cat /run/secrets/app_db_user)"
APP_PW="$(cat /run/secrets/app_db_password)"

echo "Waiting for MySQL nodes..."
for host in db1 db2 db3; do #Change the dbs into the corresponding names
	until mysqladmin ping -h "$host" --silent; do sleep 2; done
done

#This will ensure that the root can create the clusterAdmin and app user 
on each node with authorization from the network
for host in db1 db2 db3; do
	mysql -uroot -p"$ROOT_PW" -h "$host" --connect-timeout=5 -e "
		CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$ROOT_PW';
		GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
		CREATE USER IF NOT EXISTS 'clusterAdmin'@'%' WITH GRANT OPTION;
		GRANT ALL PRIVILEGES ON *.* TO 'clusterAdmin'@'%' WITH GRANT OPTION;
		CREATE USER IF NOT EXISTS '${APP_USER}'@'%' WITH GRANT OPTION;
		GRANT ALL PRIVILEGES ON firefly.* to '${APP_USER}'@'%';
		FLUDH PRIVILEGES;
	"
done

#Uses the MySQL Shell to add instances and create the cluster. (Replace db1 
with your username if necessary)
mysqlsh --sql -uroot -p"$ROOT_PW" -h db1 -e "SET PERSIST group_replication_bootstrap_group=ON"
mysqlsh --js -u clusterAdmin -p"$CLUSTER_ADMIN_PW" -h db1 -e "dba.createCluster('ffCluster')"
mysqlsh --sql -uroot -p"$ROOT_PW" -h db1 -e "SET PERSIST group_replication_bootstrap_group=OFF"

#This line will start GR on the primary machine and adds the other instances 
with a Shell API script

echo "Cluster initialized."
