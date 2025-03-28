#!/bin/bash

# Download TiUP
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh

# Source TiUP environment
source ~/.bashrc

# Install TiUP cluster component
tiup cluster

# Deploy cluster1 (Primary)
tiup cluster deploy cluster1 v8.5.1 ./tidb-cluster1/topology.yaml

# Deploy cluster2 (Secondary)
tiup cluster deploy cluster2 v8.5.1 ./tidb-cluster2/topology.yaml

# Start cluster1
tiup cluster start cluster1

# Start cluster2
tiup cluster start cluster2

# Wait for clusters to be ready
sleep 30

# Create TiCDC changefeed for replication
tiup cdc cli changefeed create --pd="http://10.148.0.5:2379" \
    --sink-uri="mysql://root:@10.148.0.6:4000/" \
    --changefeed-id="replication-task-1" \
    --config="config.toml"

echo "Setup completed! You can now connect to:"
echo "Primary cluster: mysql -h 34.87.126.253 -P 4000 -u root"
echo "Secondary cluster: mysql -h 34.142.159.157 -P 4000 -u root" 

