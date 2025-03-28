# TiDB SyncPoint Demo

This repository contains a demo to verify data synchronization between two TiDB clusters using TiCDC with SyncPoint enabled.

## Overview

This demo illustrates how to use TiCDC's SyncPoint feature to verify data synchronization between a primary and secondary TiDB cluster. The demo is based on the [TiCDC Upstream and Downstream Check documentation](https://docs.pingcap.com/tidb/stable/ticdc-upstream-downstream-check/).

The demo assumes two new VM instances with the following IPs:
- Primary Cluster (Cluster 1): 10.148.0.5
- Secondary Cluster (Cluster 2): 10.148.0.6

## Directory Structure

```
├── README.md               # This file
├── check_sync.sh           # Script to check synchronization status
├── config.toml             # TiCDC SyncPoint configuration
├── setup_tidb_clusters.sh  # Script to set up TiDB clusters and TiCDC
├── tidb-cluster1/          # Primary cluster configuration
│   └── topology.yaml      
└── tidb-cluster2/          # Secondary cluster configuration
    └── topology.yaml
```

## How It Works

### 1. Setting Up TiDB Clusters

The `setup_tidb_clusters.sh` script performs the following:

1. Downloads and installs TiUP (TiDB package manager)
2. Deploys two TiDB clusters using the topology files
3. Starts both clusters
4. Sets up a TiCDC changefeed for replication with SyncPoint enabled

The configuration in `config.toml` enables SyncPoint with:
- 30-second synchronization interval
- 1-hour data retention policy

### 2. Creating Demo Table

Before running the check script, you need to create a demo table in the primary cluster:

```sql
CREATE TABLE test.t (i INT PRIMARY KEY AUTO_INCREMENT);
```

### 3. Checking Synchronization

The `check_sync.sh` script demonstrates SyncPoint functionality by:

1. Inserting a new row into the primary cluster
2. Getting the transaction timestamp and last insert ID
3. Monitoring the SyncPoint timestamps from the secondary cluster
4. Verifying when the data has been successfully synchronized
5. Checking if the inserted row is available in the secondary cluster

## Usage Instructions

1. Make the scripts executable:
   ```
   chmod +x setup_tidb_clusters.sh check_sync.sh
   ```

2. Run the setup script to deploy the TiDB clusters and configure replication:
   ```
   ./setup_tidb_clusters.sh
   ```

3. Connect to the primary cluster and create the test table:
   ```
   mysql -h 10.148.0.5 -P 4000 -u root
   ```
   ```sql
   CREATE DATABASE IF NOT EXISTS test;
   CREATE TABLE test.t (i INT PRIMARY KEY AUTO_INCREMENT);
   ```

4. Run the check script to verify synchronization:
   ```
   ./check_sync.sh
   ```

## Expected Output

When running the check script, you'll see output similar to:

```
Initial commit_ts: 2025-03-28 12:34:56.789
Last insert id: 1
Current primary_ts: 2025-03-28 12:34:57.123, secondary_ts: 2025-03-28 12:34:56.456
In Sync
Current primary_ts: 2025-03-28 12:34:59.789, secondary_ts: 2025-03-28 12:34:58.123
Synced
Last inserted ID 1 has synced.
```

This indicates that:
1. A row was inserted in the primary cluster
2. The SyncPoint mechanism tracked synchronization timestamps
3. The data was successfully replicated to the secondary cluster

## Notes

- Ensure you have MySQL client installed on your machine
- The script connects to the TiDB clusters using the default root user without password
- The demo utilizes TiCDC's SyncPoint feature which was introduced in TiDB v6.1.0
