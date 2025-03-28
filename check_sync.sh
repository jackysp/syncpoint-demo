#!/bin/bash

# This script checks the synchronization status of two TiDB clusters.
# It retrieves the commit timestamp and last insert ID from cluster1,
# and then checks the syncpoint timestamps from cluster2.
# It will print the current primary and secondary timestamps, and
# whether the last inserted ID has synced or not.
# Usage: ./check_sync.sh
# Ensure the script is executable
# chmod +x check_sync.sh
# Ensure you have MySQL client installed and configured to connect to the clusters

# This script assumes there's a table `t` in the primary cluster. The table schema is:
# CREATE TABLE t (i INT PRIMARY KEY AUTO_INCREMENT);
# The script also assumes that you have already created a changefeed named 'replication-task-1' in cluster2.
# And the two clusters IP addresses are:
# Cluster 1: 10.148.0.5
# Cluster 2: 10.148.0.6

mysql_cluster1() {
    mysql -h 10.148.0.5 -P 4000 -u root -Dtest -N -e "$1"
}

# Function for executing MySQL commands on cluster2
mysql_cluster2() {
    mysql -h 10.148.0.6 -P 4000 -u root -Dtest -N -e "$1"
}

# Function to get current timestamp and last insert id from cluster1
get_txn_info() {
    mysql_cluster1 "
    insert into t values ();
    select JSON_EXTRACT(@@tidb_last_txn_info, '$.commit_ts') as commit_ts, last_insert_id() as last_id;"
}

# Function to convert TSO to human-readable timestamp
parse_tso() {
    local cluster=$1
    local tso=$2
    
    if [ "$cluster" = "1" ]; then
        mysql_cluster1 "SELECT tidb_parse_tso($tso);"
    else
        mysql_cluster2 "SELECT tidb_parse_tso($tso);"
    fi
}

# Function to get primary_ts and secondary_ts from cluster2
get_syncpoint_timestamps() {
    mysql_cluster2 "
    select primary_ts, secondary_ts from tidb_cdc.syncpoint_v1 
    where changefeed = 'replication-task-1' 
    order by created_at desc limit 1;"
}

# Get initial begin_ts and last_id
read -r begin_ts last_id <<< $(get_txn_info)
echo "Initial commit_ts: $(parse_tso 1 "$begin_ts")"
echo "Last insert id: $last_id"

# Main loop
while true; do
    read -r primary_ts secondary_ts <<< $(get_syncpoint_timestamps)
    
    if [ -z "$primary_ts" ]; then
        echo "No syncpoint found yet. Waiting..."
        sleep 5
        continue
    fi
    
    primary_time=$(parse_tso 2 "$primary_ts")
    secondary_time=$(parse_tso 2 "$secondary_ts")
    echo "Current primary_ts: $primary_time, secondary_ts: $secondary_time"
    
    if [ "$begin_ts" -gt "$primary_ts" ]; then
        echo "In Sync"
        sleep 2
    else
        echo "Synced"
        
        # Check if the last inserted ID has synced
        synced_id=$(mysql_cluster2 "
        SELECT i FROM t AS OF TIMESTAMP tidb_parse_tso($secondary_ts) WHERE i = $last_id;")
        
        if [ -n "$synced_id" ]; then
            echo "Last inserted ID $last_id has synced."
        else
            echo "Last inserted ID $last_id has not synced yet."
        fi
        break
    fi
done