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

set -o errexit
set -o nounset

# The following can be used to run master and worker-specific code

# Get the master list
MASTERS=$(curl \
    "http://metadata/computeMetadata/v1/instance/attributes/cluster-master" \
    -H "X-Google-Metadata-Request: True")
HOSTNAME=$(hostname --short)

echo "MASTER instances: ${MASTERS}"
echo "This instance: ${HOSTNAME}"

declare i_am_master=0
for master in $MASTERS; do
  if [[ "${master}" == "$HOSTNAME" ]]; then
    i_am_master=1
    break
  fi
done

if [[ $i_am_master -eq 1 ]]; then
  echo "I am a master"
else
  echo "I am NOT a master"
fi

# Key off existence of the "data" mount point to determine whether
# this is the first boot.
if [[ ! -e /mnt/data ]]; then

  # This is a good place to do things that only need to be done the
  # first time an instance is started.

  mkdir -p /mnt/data
fi

# Get the device name of the "data" disk
DISK_DEV=$(basename $(readlink /dev/disk/by-id/google-$(hostname)-data))

# Mount it
/usr/share/google/safe_format_and_mount \
  -m "mkfs.ext4 -F -q" /dev/$DISK_DEV /mnt/data #&> /tmp/mount.txt

chmod 777 /mnt/data

