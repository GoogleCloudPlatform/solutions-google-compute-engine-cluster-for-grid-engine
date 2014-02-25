#!/bin/bash

# Copyright 2014 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# This script is a generic cluster bring-up script in the model of
# one or more "master" instances and one or more "worker" instances.
#
# The names of the hosts can be controlled with the MASTER_NODE_NAME_PATTERN
# and the WORKER_NODE_NAME_PATTERN.
#
# The number of hosts can be controlled with the MASTER_NODE_COUNT
# and the WORKER_NODE_COUNT.
#
# To use this script review and update the "readonly" parameters
# below. Then run:
#
#   ./cluster_setup.sh up-full   # Full bring-up (including disks)
#   ./cluster_setup.sh down-full # Full teardown (including disks)
#
#   ./cluster_setup.sh up        # Bring-up assumes disks exist
#   ./cluster_setup.sh down      # Teardown does not destroy disks
#
# So a common model would be:
#
# First bring up:
#   ./cluster_setup.sh up-full
#
# Repeat:
#   Bring-down:
#     ./cluster_setup.sh down
#
#   Bring-up:
#     ./cluster_setup.sh up
#

set -o errexit
set -o nounset

source cluster_properties.sh

### Begin functions

# Master node name formatter
function master_node_name() {
  local instance_id="$1"
  printf $MASTER_NODE_NAME_PATTERN $instance_id
}
readonly -f master_node_name

# Master boot disk name formatter
function master_boot_disk() {
  local instance_id="$1"
  printf $MASTER_BOOT_DISK_PATTERN $instance_id
}
readonly -f master_boot_disk

# Master data disk name formatter
function master_data_disk() {
  local instance_id="$1"
  printf $MASTER_DATA_DISK_PATTERN $instance_id
}
readonly -f master_data_disk

# Worker node name formatter
function worker_node_name() {
  local instance_id="$1"
  printf $WORKER_NODE_NAME_PATTERN $instance_id
}
readonly -f worker_node_name

# Worker boot disk name formatter
function worker_boot_disk() {
  local instance_id="$1"
  printf $WORKER_BOOT_DISK_PATTERN $instance_id
}
readonly -f worker_boot_disk

# Worker data disk name formatter
function worker_data_disk() {
  local instance_id="$1"
  printf $WORKER_DATA_DISK_PATTERN $instance_id
}
readonly -f worker_data_disk

# Utility function used by the *_list() functions below to generate
# lists of host and disk names
function get_list_by_fn() {
  local fn="$1"
  local count="$2"

  local list=""
  for ((i=0; i < $count; i++)); do
    local name=$($fn $i)
    list="$list $name"
  done

  echo -n $list
}
readonly -f get_list_by_fn

# Returns the list of master node names
function master_node_list() {
  get_list_by_fn master_node_name $MASTER_NODE_COUNT
}
readonly -f master_node_list

# Returns the list of master boot disk names
function master_boot_disk_list() {
  get_list_by_fn master_boot_disk $MASTER_NODE_COUNT
}
readonly -f master_boot_disk_list

# Returns the list of master data disk names
function master_data_disk_list() {
  get_list_by_fn master_data_disk $MASTER_NODE_COUNT
}
readonly -f master_data_disk_list

# Returns the list of worker node names
function worker_node_list() {
  get_list_by_fn worker_node_name $WORKER_NODE_COUNT
}
readonly -f worker_node_list

# Returns the list of worker boot disk names
function worker_boot_disk_list() {
  get_list_by_fn worker_boot_disk $WORKER_NODE_COUNT
}
readonly -f worker_boot_disk_list

# Returns the list of worker data disk names
function worker_data_disk_list() {
  get_list_by_fn worker_data_disk $WORKER_NODE_COUNT
}
readonly -f worker_data_disk_list

# Returns the name of an output file for the specified PID
function get_out_file() {
  local pid=$1
  local out=$2

  echo -n "${SCRIPT_LOG_DIR}/${pid}.${out}.log"
}
readonly -f get_out_file

# Adds the specified master node as a background task
function add_master_node() {
  local masters="$1"
  local instance_id="$2"

  local name=$(master_node_name $instance_id)
  local boot_disk=$(master_boot_disk $instance_id)
  local data_disk=$(master_data_disk $instance_id)

  ( export BPID=$(sh -c 'echo $PPID');
    exec \
      gcutil addinstance "$name" \
        --zone=${MASTER_NODE_ZONE} \
        --disk="${boot_disk},boot" \
        --disk="${data_disk}" \
        --machine_type=${MASTER_NODE_MACHINE_TYPE} \
        --network=${CLUSTER_NETWORK} \
        --metadata="cluster-master:${masters}" \
        --metadata_from_file=startup-script:instance_startup_script.sh \
        --service_account_scopes=${MASTER_NODE_SCOPE} \
    1> ${SCRIPT_LOG_DIR}/${BPID}.out.log \
    2> ${SCRIPT_LOG_DIR}/${BPID}.err.log ) &
}
readonly -f add_master_node

# Adds the specified worker node as a background task
function add_worker_node() {
  local masters="$1"
  local instance_id="$2"

  local name=$(worker_node_name $i)
  local boot_disk=$(worker_boot_disk $i)
  local data_disk=$(worker_data_disk $i)

  ( export BPID=$(sh -c 'echo $PPID');
    exec \
      gcutil addinstance "$name" \
        --zone=${WORKER_NODE_ZONE} \
        --disk="${boot_disk},boot" \
        --disk="${data_disk}" \
        --machine_type=${WORKER_NODE_MACHINE_TYPE} \
        --network=${CLUSTER_NETWORK} \
        --metadata="cluster-master:${masters}" \
        --metadata_from_file=startup-script:instance_startup_script.sh \
        --service_account_scopes=${WORKER_NODE_SCOPE} \
    1> ${SCRIPT_LOG_DIR}/${BPID}.out.log \
    2> ${SCRIPT_LOG_DIR}/${BPID}.err.log ) &
}
readonly -f add_worker_node

# Accepts a list of hosts or disks and returns a list of those that
# exist and need to be deleted.
function get_delete_list() {
  local in_type="$1"

  shift
  local in_list="$@"

  # Get the current list of instances/disks
  # If this fails, we DO want the script to blow up.

  # in_list should be space separated
  # Replace spaces with pipes (|)

  local filter=$(echo $in_list | tr ' ' '|')
  local result=$(gcutil list${in_type} --format=names \
                                       --sort_by=name \
                                       --filter="name eq ($filter)")

  # Names come back zone/type/name
  # Return just the names
  echo -n "$result" | awk -F / '{print $3}' | sort
}
readonly -f get_delete_list

### End functions

### Begin MAIN execution

# Grab the operation (up | down) from the command line
readonly OPERATION=${1:-}

readonly MASTER_NODE_LIST=$(master_node_list)
readonly MASTER_BOOT_DISK_LIST=$(master_boot_disk_list)
readonly MASTER_DATA_DISK_LIST=$(master_data_disk_list)

readonly WORKER_NODE_LIST=$(worker_node_list)
readonly WORKER_BOOT_DISK_LIST=$(worker_boot_disk_list)
readonly WORKER_DATA_DISK_LIST=$(worker_data_disk_list)

declare full=0
if [[ $OPERATION =~ -full$ ]]; then
  full=1
fi

mkdir -p $SCRIPT_LOG_DIR

if [[ $OPERATION =~ ^up ]]; then
  if [[ $full == 1 ]]; then
    echo "Creating master boot disk(s): ${MASTER_BOOT_DISK_LIST}"
    gcutil adddisk ${MASTER_BOOT_DISK_LIST} \
      --zone=$MASTER_NODE_ZONE \
      --source_image=$MASTER_NODE_IMAGE

    echo "Creating master data disk(s): ${MASTER_DATA_DISK_LIST}"
    gcutil adddisk ${MASTER_DATA_DISK_LIST} \
      --zone=$MASTER_NODE_ZONE \
      --size_gb=$MASTER_NODE_DISK_SIZE_GB

    echo "Creating worker boot disk(s): ${WORKER_BOOT_DISK_LIST}"
    gcutil adddisk ${WORKER_BOOT_DISK_LIST} \
      --zone=$WORKER_NODE_ZONE \
      --source_image=$WORKER_NODE_IMAGE

    echo "Creating worker data disk(s): ${WORKER_DATA_DISK_LIST}"
    gcutil adddisk ${WORKER_DATA_DISK_LIST} \
      --zone=$WORKER_NODE_ZONE \
      --size_gb=$WORKER_NODE_DISK_SIZE_GB
  fi

  for ((i = 0; i < $MASTER_NODE_COUNT; i++)) do
    echo "Creating instance $(master_node_name $i)"
    add_master_node "$MASTER_NODE_LIST" $i
  done

  for ((i = 0; i < $WORKER_NODE_COUNT; i++)) do
    echo "Creating instance $(worker_node_name $i)"
    add_worker_node "$MASTER_NODE_LIST" $i
  done

  # All of the "add_*_host" calls were put in the background
  # Now wait for them to finish
  echo "Waiting for instances..."
  for CHILD_PID in $(jobs -p); do
    if ! wait ${CHILD_PID}; then
      echo "Process ${CHILD_PID} exited with error";
      cat ${SCRIPT_LOG_DIR}/${CHILD_PID}.out.log
      cat ${SCRIPT_LOG_DIR}/${CHILD_PID}.err.log
    fi

    rm -f ${SCRIPT_LOG_DIR}/${CHILD_PID}.out.log
    rm -f ${SCRIPT_LOG_DIR}/${CHILD_PID}.err.log
  done

  # Emit list of hosts in the cluster:
  filter=$(echo $MASTER_NODE_LIST $WORKER_NODE_LIST | tr ' ' '|')
  gcutil listinstances --filter="name eq ($filter)"

elif [[ $OPERATION =~ ^down ]]; then
  # Get the list of instances to delete
  INSTANCE_DELETE_LIST=$(get_delete_list "instances" \
                                         "$MASTER_NODE_LIST" \
                                         "$WORKER_NODE_LIST")

  if [[ -n $INSTANCE_DELETE_LIST ]]; then
    echo "Deleting instances:"
    echo "$INSTANCE_DELETE_LIST" | sed -e 's/^/  /'

    gcutil deleteinstance --force --nodelete_boot_pd $INSTANCE_DELETE_LIST
  else
    echo "No instances to delete"
  fi

  if [[ $full -eq 1 ]]; then
    # Get the list of disks to delete
    DISK_DELETE_LIST=$(get_delete_list "disks" \
                                       "$MASTER_BOOT_DISK_LIST" \
                                       "$MASTER_DATA_DISK_LIST" \
                                       "$WORKER_BOOT_DISK_LIST" \
                                       "$WORKER_DATA_DISK_LIST")

    echo "Deleting disks:"
    echo "$DISK_DELETE_LIST" | sed -e 's/^/  /'

    if [[ -n $DISK_DELETE_LIST ]]; then
      gcutil deletedisk --force $DISK_DELETE_LIST
    else
      echo "No disks to delete"
    fi
  fi
else
  echo "Usage: $(basename $0) [up-full | up | down-full | down]"
  exit 1
fi

### End MAIN execution
