#!/bin/bash

# Copyright 2015 Insight Data Science
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

# check input arguments

if [ "$#" -ne 1 ]; then
    echo "Please specify cluster name!" && exit 1
fi

PEG_ROOT=$(dirname ${BASH_SOURCE})/../..
source ${PEG_ROOT}/util.sh

CLUSTER_NAME=$1

MASTER_PUBLIC_DNS=$(fetch_cluster_master_public_dns ${CLUSTER_NAME})
PUBLIC_DNS=$(fetch_cluster_public_dns ${CLUSTER_NAME})

single_script="${PEG_ROOT}/config/riak/setup_single.sh"

# Install and configure nodes for Riak
for dns in ${PUBLIC_DNS}; do
  run_script_on_node ${dns} ${single_script} &
done

wait

# wait for riak to start on individual nodes
for i in {0..20}; do echo "."; sleep 0.5; done

hostnames=($(fetch_cluster_hostnames ${CLUSTER_NAME}))
args=(${hostnames[0]})

# script to form a riak cluster from individual riak nodes 
single_script="${PEG_ROOT}/config/riak/create_cluster.sh"
PUBLIC_DNS=$(fetch_cluster_public_dns ${CLUSTER_NAME})
PUBLIC_DNS=($PUBLIC_DNS)
PUBLIC_DNS=(${PUBLIC_DNS[@]:1})

echo -e "Configuring nodes to form a cluster"

for dns in ${PUBLIC_DNS[@]}; do
  run_script_on_node ${dns} ${single_script} ${args} &
  wait
done

# wait for riak cluster formation to complete
for i in {0..10}; do echo "."; sleep 0.5; done

# stop riak after setup
PUBLIC_DNS=$(fetch_cluster_public_dns ${CLUSTER_NAME})
stop_cmd="sudo /etc/init.d/riak stop"
for dns in ${PUBLIC_DNS}; do
  run_cmd_on_node ${dns} ${stop_cmd} &
done

wait

echo "Riak configuration complete!"

