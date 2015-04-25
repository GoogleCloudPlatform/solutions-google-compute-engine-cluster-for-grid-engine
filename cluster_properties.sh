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

# Select a prefix for the instance names in your cluster
readonly CLUSTER_PREFIX=my-grid

# Name of GCE network to add instances to
readonly CLUSTER_NETWORK=default

# By default, instance and disk names will be of the form:
#   Master:     my-grid-mm
#     boot:     my-grid-mm
#     data:     my-grid-mm-data
#   Workers: my-grid-ww-<number>
#     boot:     my-grid-ww-<number>
#     data:     my-grid-ww-<number>-data
#
readonly MASTER_NODE_NAME_PATTERN="${CLUSTER_PREFIX}-mm"
readonly MASTER_BOOT_DISK_PATTERN="${CLUSTER_PREFIX}-mm"
readonly MASTER_DATA_DISK_PATTERN="${CLUSTER_PREFIX}-mm-data"

readonly WORKER_NODE_NAME_PATTERN="${CLUSTER_PREFIX}-ww-%d"
readonly WORKER_BOOT_DISK_PATTERN="${CLUSTER_PREFIX}-ww-%d"
readonly WORKER_DATA_DISK_PATTERN="${CLUSTER_PREFIX}-ww-%d-data"

# By default all hosts will be 4 core standard instances
# in the zone us-central1-a, running debian-7
readonly MASTER_NODE_MACHINE_TYPE=n1-standard-4
readonly MASTER_NODE_ZONE=us-central1-a
readonly MASTER_NODE_IMAGE=debian-7
readonly MASTER_NODE_DISK_SIZE=500GB
readonly MASTER_NODE_SCOPE=

readonly WORKER_NODE_MACHINE_TYPE=n1-standard-4
readonly WORKER_NODE_ZONE=us-central1-a
readonly WORKER_NODE_IMAGE=debian-7
readonly WORKER_NODE_DISK_SIZE=500GB
readonly WORKER_NODE_SCOPE=

# Specify the number of each node type
readonly MASTER_NODE_COUNT=1
readonly WORKER_NODE_COUNT=2

# Output file on the local workstation for logs
readonly SCRIPT_LOG_DIR=/tmp
