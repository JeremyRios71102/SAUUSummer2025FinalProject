FROM google/cloud-sdk:slim
RUN apt-get update && apt-get install -y --no-install-recommends mysql-client ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY entrypoint.sh backup.sh /app/
RUN chmod +x /app/*.sh
ENTRYPOINT ["/app/entrypoint.sh"]
