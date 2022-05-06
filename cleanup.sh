#!/bin/bash

shopt -s expand_aliases

# Source the variables and functions in utilities.sh
. utilities.sh

# Make sure kubectl is installed. Create an alias if not.
# This needs to be done before other files are sourced.
test_for_kubectl

COMMAND="cleanup"

# Source the functions in other files
. variables.sh
. generate-yaml.sh
. labels.sh
. multi-cluster.sh

determine-default-data
process-help $1

if [ "$FT_VARS" == true ]; then
  dump-working-data
fi


# Call query_labels() to set flags so know what to delete
FT_SRIOV_SERVER=false
FT_NORMAL_CLIENT=false
FT_SRIOV_CLIENT=false
query_labels

if [ "$FT_CLIENTONLY" == true ]; then
  FT_SRIOV_SERVER=false
fi

if [ "$FT_HOSTONLY" == false ]; then
  # Delete normal Pods and Service
  if [ "$FT_NORMAL_CLIENT" == true ]; then
    kubectl delete -f ./manifests/yamls/client-daemonSet.yaml
  fi
  if [ "$FT_SRIOV_CLIENT" == true ]; then
    kubectl delete -f ./manifests/yamls/client-daemonSet-sriov.yaml
  fi

  if [ "$FT_CLIENTONLY" == false ]; then
    if [ "$FT_SRIOV_SERVER" == true ]; then
      kubectl delete -f ./manifests/yamls/iperf-server-pod-v4-sriov.yaml
      kubectl delete -f ./manifests/yamls/http-server-pod-v4-sriov.yaml
    else
      kubectl delete -f ./manifests/yamls/iperf-server-pod-v4.yaml
      kubectl delete -f ./manifests/yamls/http-server-pod-v4.yaml
    fi

    kubectl delete -f ./manifests/yamls/svc-nodePort.yaml
    kubectl delete -f ./manifests/yamls/svc-clusterIP.yaml
  fi
fi

# Delete HOST backed Pods and Service
if [ "$FT_CLIENTONLY" == false ]; then
  kubectl delete -f ./manifests/yamls/svc-nodePort-host.yaml
  kubectl delete -f ./manifests/yamls/svc-clusterIP-host.yaml
  kubectl delete -f ./manifests/yamls/iperf-server-pod-v4-host.yaml
  kubectl delete -f ./manifests/yamls/http-server-pod-v4-host.yaml
fi
kubectl delete -f ./manifests/yamls/client-daemonSet-host.yaml
kubectl delete -f ./manifests/yamls/tools-daemonSet.yaml


if [ "$FT_SRIOV_SERVER" == true ] || [ "$FT_SRIOV_CLIENT" == true ]; then
  kubectl delete -f ./manifests/yamls/netAttachDef-sriov.yaml
fi

del_labels

if [ "$FT_NAMESPACE" != default ]; then
  kubectl delete -f ./manifests/yamls/namespace.yaml
fi

if [ "$CLEAN_ALL" == true ]; then
  rm -rf manifests/yamls/*.yaml
  rm -rf iperf-logs/*.txt
  rm -rf ovn-traces/*.txt
fi
