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
├── check_sync.sh           # Original script to check synchronization status
├── check_sync_new.sh       # New script to check existing record sync status
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

Before running the check scripts, you need to create a demo table in the primary cluster:

```sql
CREATE TABLE test.t (i INT PRIMARY KEY AUTO_INCREMENT);
```

### 3. Checking Synchronization

There are two scripts available for checking synchronization:

#### check_sync.sh
The original script demonstrates SyncPoint functionality by:
1. Inserting a new row into the primary cluster
2. Getting the transaction timestamp and last insert ID
3. Monitoring the SyncPoint timestamps from the secondary cluster
4. Verifying when the data has been successfully synchronized
5. Checking if the inserted row is available in the secondary cluster

#### check_sync_new.sh
The new script provides a more flexible way to check synchronization by:
1. Taking a record ID as input
2. Retrieving the record's commit timestamp from MVCC info
3. Monitoring the SyncPoint timestamps from the secondary cluster
4. Verifying when the data has been successfully synchronized
5. Checking if the specified record is available in the secondary cluster

##### Handling Different Table Types

The `check_sync_new.sh` script can handle different types of tables:

1. **Single Column Primary Key** (Default case):
   ```sql
   CREATE TABLE t (i INT PRIMARY KEY AUTO_INCREMENT);
   ```
   Usage: `./check_sync_new.sh 1`

2. **Clustered Primary Key**:
   ```sql
   CREATE TABLE t1 (i varchar(20), j varchar(20), primary key (i, j));
   ```
   The script can be modified to use multiple arguments for the primary key:
   ```bash
   TIDB_ENCODE_RECORD_KEY('test', 't1', 'a', 'b')
   ```

3. **Table Without Primary Key**:
   ```sql
   CREATE TABLE t2 (i int);
   ```
   First, get the table row ID:
   ```sql
   SELECT _tidb_rowid, i FROM t2;
   ```
   Then use the `_tidb_rowid` value as input to the script.

## Usage Instructions

1. Make the scripts executable:
   ```
   chmod +x setup_tidb_clusters.sh check_sync.sh check_sync_new.sh
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

4. Run either check script to verify synchronization:

   Using the original script:
   ```
   ./check_sync.sh
   ```

   Using the new script (specify a record ID):
   ```
   ./check_sync_new.sh 1
   ```

## Expected Output

When running the check scripts, you'll see output similar to:

For `check_sync.sh`:
```
Initial commit_ts: 2025-03-28 12:34:56.789
Last insert id: 1
Current primary_ts: 2025-03-28 12:34:57.123, secondary_ts: 2025-03-28 12:34:56.456
In Sync
Current primary_ts: 2025-03-28 12:34:59.789, secondary_ts: 2025-03-28 12:34:58.123
Synced
Last inserted ID 1 has synced.
```

For `check_sync_new.sh`:
```
Checking sync status for record ID: 1
Commit timestamp: 2025-03-28 12:34:56.789
Current primary_ts: 2025-03-28 12:34:57.123, secondary_ts: 2025-03-28 12:34:56.456
In Sync
Current primary_ts: 2025-03-28 12:34:59.789, secondary_ts: 2025-03-28 12:34:58.123
Synced
Record ID 1 has synced.
```

Possible error messages:
- If the record doesn't exist: "Error: Record ID <id> does not exist in the primary cluster"
- If no syncpoint is found: "No syncpoint found yet. Waiting..."

## Notes

- Ensure you have MySQL client installed on your machine
- The script connects to the TiDB clusters using the default root user without password
- The demo utilizes TiCDC's SyncPoint feature which was introduced in TiDB v6.1.0
