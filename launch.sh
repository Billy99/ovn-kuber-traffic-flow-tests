#!/bin/bash

# source the functions in generate-yaml.sh and labels.sh
. generate-yaml.sh
. labels.sh

#
# Default values (possible to override)
#

SRIOV_RESOURCE_NAME=${SRIOV_RESOURCE_NAME:-openshift.io/mlnx_bf}
TEST_IMAGE=${TEST_IMAGE:-quay.io/billy99/ft-base-image:0.6}

HTTP_CLUSTERIP_POD_SVC_PORT=${HTTP_CLUSTERIP_POD_SVC_PORT:-8080}
HTTP_CLUSTERIP_HOST_SVC_PORT=${HTTP_CLUSTERIP_HOST_SVC_PORT:-8081}
HTTP_NODEPORT_POD_SVC_PORT=${HTTP_NODEPORT_POD_SVC_PORT:-30080}
HTTP_NODEPORT_HOST_SVC_PORT=${HTTP_NODEPORT_HOST_SVC_PORT:-30081}

IPERF_CLUSTERIP_POD_SVC_PORT=${IPERF_CLUSTERIP_POD_SVC_PORT:-5201}
IPERF_CLUSTERIP_HOST_SVC_PORT=${IPERF_CLUSTERIP_HOST_SVC_PORT:-5202}
IPERF_NODEPORT_POD_SVC_PORT=${IPERF_NODEPORT_POD_SVC_PORT:-30201}
IPERF_NODEPORT_HOST_SVC_PORT=${IPERF_NODEPORT_HOST_SVC_PORT:-30202}
generate_yamls

FT_LABEL_ACTION=add
FT_SMARTNIC_SERVER=false
FT_NORMAL_CLIENT=false
FT_SMARTNIC_CLIENT=false
manage_labels

if [ "$FT_SMARTNIC_SERVER" == true ] || [ "$FT_SMARTNIC_CLIENT" == true ]; then
  kubectl create -f ./manifests/yamls/netAttachDef-sriov.yaml
fi

# Create Cluster Networked Pods and Services
kubectl apply -f ./manifests/yamls/svc-nodePort.yaml
kubectl apply -f ./manifests/yamls/svc-clusterIP.yaml

# Launch "smartnic" daemonset as well if node has it enabled 
if [ "$FT_SMARTNIC_SERVER" == true ]; then
  kubectl apply -f ./manifests/yamls/http-server-pod-v4-smartNic.yaml
  kubectl apply -f ./manifests/yamls/iperf-server-pod-v4-smartNic.yaml
else
  kubectl apply -f ./manifests/yamls/http-server-pod-v4.yaml
  kubectl apply -f ./manifests/yamls/iperf-server-pod-v4.yaml
fi

if [ "$FT_NORMAL_CLIENT" == true ]; then
  kubectl apply -f ./manifests/yamls/client-daemonSet.yaml
fi
if [ "$FT_SMARTNIC_CLIENT" == true ]; then
  kubectl apply -f ./manifests/yamls/client-daemonSet-smartNic.yaml
fi

# Create Host networked Pods and Services
kubectl apply -f ./manifests/yamls/svc-nodePort-host.yaml
kubectl apply -f ./manifests/yamls/svc-clusterIP-host.yaml
kubectl apply -f ./manifests/yamls/http-server-pod-v4-host.yaml
kubectl apply -f ./manifests/yamls/iperf-server-pod-v4-host.yaml
kubectl apply -f ./manifests/yamls/client-daemonSet-host.yaml
