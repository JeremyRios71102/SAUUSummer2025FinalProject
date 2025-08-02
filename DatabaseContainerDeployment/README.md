# Firefly III – Data‑Management Layer (MySQL InnoDB Cluster)

> **Purpose**  This README walks you **step‑by‑step** through setting up the high‑availability MySQL back‑end, persistent storage, and automated backups for the Firefly III stack on **Ubuntu 25.04** running **inside Google Cloud Console** (GCE VMs + Cloud Shell) – **console‑only**, no GUI.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Repo / Directory Layout](#2-repo--directory-layout)
3. [Prepare Your GCE VMs](#3-prepare-your-gce-vms)

    3a. [Install Docker & CLI tools](#31-install-docker--cli-tools)
    3b. [Initialise Docker Swarm](#32-initialise-docker-swarm)
    3c. [Label Nodes for DB Placement](#33-label-nodes-for-db-placement)
4. [Provision Persistent Storage](#4-provision-persistent-storage)
5. [Create Swarm Secrets](#5-create-swarm-secrets)
6. [Build the Backup Image](#6-build-the-backup-image)
7. [Deploy the Stack](#7-deploy-the-stack)
8. [Validate the Deployment](#8-validate-the-deployment)
9. [Day‑2 Operations](#9-day‑2-operations)
10. [Troubleshooting](#10-troubleshooting)
11. [Cleanup](#11-cleanup)

---

## 1. Prerequisites

| Item                              | Notes                                                                                                                   |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Google project**                | Billing enabled; Cloud Shell activated.                                                                                 |
| **3× Ubuntu 25.04 GCE instances** | Static internal names: `db-1`, `db-2`, `db-3`. Each has an *extra* blank disk at **/dev/sdb** (≥20 GiB) for MySQL data. |
| **Firewall**                      | Allow TCP 3306, 33060–33061 between DB nodes; port 80 (or 8080 ext) to Firefly service.                                 |
| **Service‑account key JSON**      | Grants write to a GCS bucket for backups; download locally.                                                             |
| **Bucket**                        | `gs://<your‑bucket>/firefly-backups` already exists.                                                                    |

> **Cloud Shell only?**  You can SSH into each VM directly from Cloud Shell with `gcloud compute ssh db-1` (repeat for others).

---

## 2. Repo / Directory Layout

Here's a directory on how the app should be laid out.

```
DatabaseContainerDeployment/
├── stack.yml                 # Master compose file (app + DB + backup)
├── scripts/
│   └── lvm-setup.sh          # Host‑level persistent volume creator
├── mysql/
│   ├── conf/
│   │   ├── my1.cnf
│   │   ├── my2.cnf
│   │   └── my3.cnf
│   ├── cluster-init.sh       # One‑shot bootstrap shell script
│   └── cluster-init.js       # JS API calls for MySQL Shell
└── backup/
    ├── Dockerfile            # Tiny image with gsutil + mysqldump
    ├── entrypoint.sh         # Cron runner
    └── backup.sh             # Actual backup code
```

Clone or copy these files onto the **Swarm manager** VM (or Cloud Shell workspace):

```bash
# Cloud Shell
mkdir -p ~/firefly-ha && cd ~/firefly-ha
# Copy/paste each file or clone from your fork
```

---

## 3. Prepare Your GCE VMs

### 3.1 Install Docker & CLI tools (run on **each** VM)

```bash
sudo apt update && sudo apt install -y \
    docker.io docker-compose-plugin lvm2 \
    gnupg2 curl cron
# Enable & start Docker
sudo systemctl enable --now docker
# (Optional) allow your user to run Docker without sudo
sudo usermod -aG docker $USER
```

Log out and sign back in, this should put you in the docker group.

### 3.2 Initialise Docker Swarm (on one **manager** VM)

```bash
# Replace with the manager's primary NIC private IP
MY_IP=$(hostname -I | awk '{print $1}')
docker swarm init --advertise-addr "$MY_IP"
```

A 'docker swarm join...' command will be shown, copy that command so you can log in.

> **Join the other two nodes** (run on `db-2` & `db-3`):

```bash
# Example (paste the token printed above)
sudo docker swarm join --token <token> <manager_ip>:2377
```

### 3.3 Label Nodes for DB Placement (manager only)

```bash
docker node update --label-add mysql=1 db-1
docker node update --label-add mysql=2 db-2
docker node update --label-add mysql=3 db-3
```

---

## 4. Provision Persistent Storage

Copy `scripts/lvm-setup.sh` to each DB node and **run as root**:

```bash
scp scripts/lvm-setup.sh db-1:~/
# Change the device name if necessary
ssh db-1 "sudo bash ~/lvm-setup.sh /dev/sdb"
```

Result: data directory **/mnt/mysql** exists, formatted, mounted, and permissioned for UID `999` (MySQL).

---

## 5. Create Swarm Secrets (manager only)

You may use your own password terms, just make sure they're strong. Below is an example:

```bash
# 1) Create local files with strong secrets
printf '%s' 'Str0ngRoot!'           > mysql_root_password.txt
printf '%s' 'Str0ngApp!'            > app_db_password.txt
printf '%s' 'firefly_user'          > app_db_user.txt
printf '%s' 'Str0ngCluster!'        > cluster_admin_password.txt
printf '%s' 'Str0ngRouter!'         > router_bootstrap_password.txt
cp ~/Downloads/your-gcp-sa.json gcp_sa_key.json  # service‑account key

# 2) Load them as Swarm secrets
for s in mysql_root_password app_db_password app_db_user \
         cluster_admin_password router_bootstrap_password gcp_sa_key; do
  docker secret create "$s" "${s}.txt"
done
```

> **Never** commit these files to git; delete the plain‑text copies once secrets are loaded.

---

## 6. Build the Backup Image (manager only)

We keep the image local to the Swarm. From the project root:

```bash
docker build -t firefly/db-backup:latest ./backup
```

---

## 7. Deploy the Stack

Ensure you are in the `firefly-ha` directory (contains `stack.yml`). Then run:

```bash
# Create an overlay network if you prefer explicit control (optional)
# docker network create -d overlay firefly_network

# Deploy everything (app + db + backups)
docker stack deploy -c stack.yml firefly
```

Swarm will schedule:

* 3× `db*` MySQL containers (one per labelled node)
* 1× `db-init` job (runs once, bootstraps cluster, then exits)
* 1× `db` MySQL Router (load‑balances primary)
* 3× `firefly` app replicas
* 1× `db-backup` cron sidecar

---

## 8. Validate the Deployment

### 8.1 Check service health

```bash
docker service ls
```

You should see all services `Running` with desired replicas.

### 8.2 Inspect cluster status

```bash
# Grab the cluster_admin_password secret for convenience
CLUSTER_PW=$(docker secret inspect cluster_admin_password -f '{{.Spec.Data}}' | base64 -d)

docker run --rm --network firefly_firefly_network mysql/mysql-shell:8.0 \
  --js -u clusterAdmin -p"$CLUSTER_PW" -h db1 \
  -e "dba.getCluster().status()"
```

### 8.3 Failover test (optional)

```bash
# Stop the current primary (db1) and watch Router keep serving
docker service scale firefly_db1=0
# Wait 15–30 s, then re‑run the status command above; primary should switch.
```

---

## 9. Day‑2 Operations

| Task                 | Command                                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Scale app**        | `docker service scale firefly_firefly=5`                                                                         |
| **View backup log**  | `docker service logs -f firefly_db-backup`                                                                       |
| **Restore (quick)**  | `gsutil cp gs://<bucket>/firefly-backups/<dump>.gz .` → `gunzip` → `mysql -h db -u <user> -p firefly < dump.sql` |
| **Rotate passwords** | `docker secret rm ...` + re‑create → `docker service update --secret-rm/--secret-add`                            |

---

## 10. Troubleshooting

* `db-init` stuck?  Run `docker service logs firefly_db-init` to see why bootstrap failed (most common: wrong secret values).
* Router can’t start?  Delete its workdir volume or force‑rebootstrap:

  ```bash
  docker service rm firefly_db
  # Re‑create once cluster healthy:
  docker stack deploy -c stack.yml firefly --with-registry-auth
  ```
* MySQL node won’t join cluster – check `group_replication` config & ensure ports 33061 open between VMs.

---

## 11. Cleanup

```bash
# Remove entire stack (keeps data on /mnt/mysql)
docker stack rm firefly
# This will wipe the storage. Be careful, it can't be undone.
# sudo umount /mnt/mysql && sudo lvremove -f /dev/vgdata/lv_mysql && sudo vgremove -f vgdata && sudo pvremove /dev/sdb
# Remove secrets
for s in $(docker secret ls -q); do docker secret rm "$s"; done
```

---

### ✨ You’re done!

Firefly III should now be accessible at the external IP of whichever Swarm node published port 80. Enjoy your resilient, self‑healing, and backed‑up personal finance manager.
