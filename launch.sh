#!/bin/bash

shopt -s expand_aliases

# Source the variables and functions in utilities.sh
. utilities.sh

# Make sure kubectl is installed. Create an alias if not.
# This needs to be done before other files are sourced.
test_for_kubectl

COMMAND="launch"

# Source the functions in other files
. variables.sh
. generate-yaml.sh
. labels.sh
. multi-cluster.sh

determine-default-data
process-help $1
install_j2_renderer
generate_yamls

if [ "$FT_VARS" == true ]; then
  dump-working-data
fi

FT_SRIOV_SERVER=false
FT_NORMAL_CLIENT=false
FT_SRIOV_CLIENT=false
add_labels

if [ "$FT_CLIENTONLY" == true ]; then
  FT_SRIOV_SERVER=false
fi

if [ "$FT_NAMESPACE" != default ]; then
  echo "Creating Namespace"
  kubectl apply -f ./manifests/yamls/namespace.yaml
fi

if [ "$FT_HOSTONLY" == false ]; then
  if [ "$FT_SRIOV_SERVER" == true ] || [ "$FT_SRIOV_CLIENT" == true ]; then
    kubectl apply -f ./manifests/yamls/netAttachDef-sriov.yaml
  fi

  if [ "$FT_CLIENTONLY" == false ]; then
    # Create Cluster Networked Pods and Services
    kubectl apply -f ./manifests/yamls/svc-nodePort.yaml
    kubectl apply -f ./manifests/yamls/svc-clusterIP.yaml

    # Launch "SR-IOV" daemonset as well if node has it enabled 
    if [ "$FT_SRIOV_SERVER" == true ]; then
      kubectl apply -f ./manifests/yamls/http-server-pod-v4-sriov.yaml
      kubectl apply -f ./manifests/yamls/iperf-server-pod-v4-sriov.yaml
    else
      kubectl apply -f ./manifests/yamls/http-server-pod-v4.yaml
      kubectl apply -f ./manifests/yamls/iperf-server-pod-v4.yaml
    fi
  fi

  if [ "$FT_NORMAL_CLIENT" == true ]; then
    kubectl apply -f ./manifests/yamls/client-daemonSet.yaml
  fi
  if [ "$FT_SRIOV_CLIENT" == true ]; then
    kubectl apply -f ./manifests/yamls/client-daemonSet-sriov.yaml
  fi
fi

# Create Host networked Pods and Services
if [ "$FT_CLIENTONLY" == false ]; then
  kubectl apply -f ./manifests/yamls/svc-nodePort-host.yaml
  kubectl apply -f ./manifests/yamls/svc-clusterIP-host.yaml
  kubectl apply -f ./manifests/yamls/http-server-pod-v4-host.yaml
  kubectl apply -f ./manifests/yamls/iperf-server-pod-v4-host.yaml
fi
kubectl apply -f ./manifests/yamls/client-daemonSet-host.yaml
kubectl apply -f ./manifests/yamls/tools-daemonSet.yaml

manage_multi_cluster
