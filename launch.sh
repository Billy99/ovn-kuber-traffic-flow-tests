#!/bin/bash

# source the functions in generate-yaml.sh and labels.sh
. generate-yaml.sh
. labels.sh

#
# Default values (possible to override)
#

FT_HOSTONLY=${FT_HOSTONLY:-false}

NET_ATTACH_DEF_NAME=${NET_ATTACH_DEF_NAME:-ftnetattach}
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

dump-working-data() {
  echo
  echo "Default/Override Values:"
  echo "  Launch Control:"
  echo "    FT_HOSTONLY                        $FT_HOSTONLY"
  echo "    FT_REQ_SERVER_NODE                 $FT_REQ_SERVER_NODE"
  echo "    FT_REQ_REMOTE_CLIENT_NODE          $FT_REQ_REMOTE_CLIENT_NODE"
  echo "  From YAML Files:"
  echo "    NET_ATTACH_DEF_NAME                $NET_ATTACH_DEF_NAME"
  echo "    SRIOV_RESOURCE_NAME                $SRIOV_RESOURCE_NAME"
  echo "    TEST_IMAGE                         $TEST_IMAGE"
  echo "    HTTP_CLUSTERIP_POD_SVC_PORT        $HTTP_CLUSTERIP_POD_SVC_PORT"
  echo "    HTTP_CLUSTERIP_HOST_SVC_PORT       $HTTP_CLUSTERIP_HOST_SVC_PORT"
  echo "    HTTP_NODEPORT_POD_SVC_PORT         $HTTP_NODEPORT_POD_SVC_PORT"
  echo "    HTTP_NODEPORT_HOST_SVC_PORT        $HTTP_NODEPORT_HOST_SVC_PORT"
  echo "    IPERF_CLUSTERIP_POD_SVC_PORT       $IPERF_CLUSTERIP_POD_SVC_PORT"
  echo "    IPERF_CLUSTERIP_HOST_SVC_PORT      $IPERF_CLUSTERIP_HOST_SVC_PORT"
  echo "    IPERF_NODEPORT_POD_SVC_PORT        $IPERF_NODEPORT_POD_SVC_PORT"
  echo "    IPERF_NODEPORT_HOST_SVC_PORT       $IPERF_NODEPORT_HOST_SVC_PORT"
}

# Test for '--help'
if [ ! -z "$1" ] ; then
  if [ "$1" == help ] || [ "$1" == "--help" ] ; then
    echo
    echo "This script uses ENV Variables to control test. Here are few key ones:"
    echo "  FT_HOSTONLY                - Only host network backed pods were launched, off by default."
    echo "                               Used on DPUs. It is best to export this variable. test.sh and"
    echo "                               cleanup.sh will try to detect if it was used on launch, but"
    echo "                               false positives could occur if pods are renamed or server pod"
    echo "                               failed to come up. Example:"
    echo "                                 export FT_HOSTONLY=true"
    echo "                                 ./launch.sh"
    echo "                                 ./test.sh"
    echo "                                 ./cleanup.sh"
    echo "  FT_REQ_SERVER_NODE         - Node to run server pods on. Must be set before launching"
    echo "                               pods. Example:"
    echo "                                 FT_REQ_SERVER_NODE=ovn-worker3 ./launch.sh"
    echo "  FT_REQ_REMOTE_CLIENT_NODE  - Node to use when sending from client pod on different node"
    echo "                               from server. Example:"
    echo "                                 FT_REQ_REMOTE_CLIENT_NODE=ovn-worker4 ./test.sh"

    dump-working-data
    dump_labels
  else
    echo
    echo "Unknown input, try using \"./launch.sh --help\""
    echo
  fi

  exit 0
fi

dump-working-data
install_j2_renderer
generate_yamls

FT_LABEL_ACTION=add
FT_SMARTNIC_SERVER=false
FT_NORMAL_CLIENT=false
FT_SMARTNIC_CLIENT=false
manage_labels

if [ "$FT_HOSTONLY" == false ]; then
  if [ "$FT_SMARTNIC_SERVER" == true ] || [ "$FT_SMARTNIC_CLIENT" == true ]; then
    kubectl apply -f ./manifests/yamls/netAttachDef-sriov.yaml
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
fi

# Create Host networked Pods and Services
kubectl apply -f ./manifests/yamls/svc-nodePort-host.yaml
kubectl apply -f ./manifests/yamls/svc-clusterIP-host.yaml
kubectl apply -f ./manifests/yamls/http-server-pod-v4-host.yaml
kubectl apply -f ./manifests/yamls/iperf-server-pod-v4-host.yaml
kubectl apply -f ./manifests/yamls/client-daemonSet-host.yaml
