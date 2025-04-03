#!/bin/bash

# This script checks the synchronization status of two TiDB clusters.
# It retrieves the commit timestamp from the record's MVCC info and checks sync status.
# Usage: ./check_sync_new.sh <record_id>
# Example: ./check_sync_new.sh 1
# Ensure the script is executable
# chmod +x check_sync_new.sh
# Ensure you have MySQL client installed and configured to connect to the clusters

# This script assumes there's a table `t` in the primary cluster. The table schema is:
# CREATE TABLE t (i INT PRIMARY KEY AUTO_INCREMENT);
# The script also assumes that you have already created a changefeed named 'replication-task-1' in cluster2.
# And the two clusters IP addresses are:
# Cluster 1: 10.148.0.5
# Cluster 2: 10.148.0.6

# Check if required argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <record_id>"
    echo "Example: $0 1"
    exit 1
fi

record_id=$1

mysql_cluster1() {
    mysql -h 10.148.0.5 -P 4000 -u root -Dtest -N -e "$1"
}

# Function for executing MySQL commands on cluster2
mysql_cluster2() {
    mysql -h 10.148.0.6 -P 4000 -u root -Dtest -N -e "$1"
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

# Get commit_ts from MVCC info
begin_ts=$(mysql_cluster1 "
SELECT JSON_EXTRACT(
    JSON_EXTRACT(
        TIDB_MVCC_INFO(TIDB_ENCODE_RECORD_KEY('test', 't', $record_id)),
        '\$[0].mvcc.info.writes[0].commit_ts'
    ),
    '\$'
) as commit_ts;")

if [ -z "$begin_ts" ] || [ "$begin_ts" = "NULL" ]; then
    echo "Error: Record ID $record_id does not exist in the primary cluster"
    exit 1
fi

echo "Checking sync status for record ID: $record_id"
echo "Commit timestamp: $(parse_tso 1 "$begin_ts")"

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
        
        # Check if the record has synced
        synced_id=$(mysql_cluster2 "
        SELECT i FROM t AS OF TIMESTAMP tidb_parse_tso($secondary_ts) WHERE i = $record_id;")
        
        if [ -n "$synced_id" ]; then
            echo "Record ID $record_id has synced."
        else
            echo "Record ID $record_id has not synced yet."
        fi
        break
    fi
done 