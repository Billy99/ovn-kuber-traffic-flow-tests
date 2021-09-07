#!/bin/bash

shopt -s expand_aliases

# Source the functions in utilities.sh
. utilities.sh

# Make sure kubectl is installed. Create an alias if not.
# This needs to be done before other files are sourced.
test_for_kubectl

# Source the functions in labels.sh
. labels.sh

#
# Default values (possible to override)
#
CLEAN_ALL=${CLEAN_ALL:-false}
FT_HOSTONLY=${FT_HOSTONLY:-unknown}
HTTP_SERVER_POD_NAME=${HTTP_SERVER_POD_NAME:-ft-http-server-pod-v4}

dump-working-data() {
  echo
  echo "Default/Override Values:"
  echo "  Launch Control:"
  echo "    FT_HOSTONLY                        $FT_HOSTONLY"
  echo "    HTTP_SERVER_POD_NAME               $HTTP_SERVER_POD_NAME"
  echo "    CLEAN_ALL                          $CLEAN_ALL"
  echo "    FT_REQ_SERVER_NODE                 $FT_REQ_SERVER_NODE"
  echo "    FT_REQ_REMOTE_CLIENT_NODE          $FT_REQ_REMOTE_CLIENT_NODE"
}

# Try to determine if only host-networked pods were created.
if [ "$FT_HOSTONLY" == unknown ]; then
  TEST_HTTP_SERVER=`kubectl get pods | grep -o "$HTTP_SERVER_POD_NAME"`
  if [ -z "${TEST_HTTP_SERVER}" ]; then
    FT_HOSTONLY=true
  else
    FT_HOSTONLY=false
  fi
fi

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
    echo "  CLEAN_ALL                  - Remove all generated files (yamls from j2, iperf logs, and"
    echo "                               ovn-trace logs). Default is to leave in place. Example:"
    echo "                                 CLEAN_ALL=true ./cleanup.sh"

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

# Call query_labels() to set flags so know what to delete
FT_SRIOV_SERVER=false
FT_NORMAL_CLIENT=false
FT_SRIOV_CLIENT=false
query_labels

if [ "$FT_HOSTONLY" == false ]; then
  # Delete normal Pods and Service
  if [ "$FT_NORMAL_CLIENT" == true ]; then
    kubectl delete -f ./manifests/yamls/client-daemonSet.yaml
  fi
  if [ "$FT_SRIOV_CLIENT" == true ]; then
    kubectl delete -f ./manifests/yamls/client-daemonSet-sriov.yaml
  fi

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


# Delete HOST backed Pods and Service
kubectl delete -f ./manifests/yamls/svc-nodePort-host.yaml
kubectl delete -f ./manifests/yamls/svc-clusterIP-host.yaml
kubectl delete -f ./manifests/yamls/iperf-server-pod-v4-host.yaml
kubectl delete -f ./manifests/yamls/http-server-pod-v4-host.yaml
kubectl delete -f ./manifests/yamls/client-daemonSet-host.yaml


if [ "$FT_SRIOV_SERVER" == true ] || [ "$FT_SRIOV_CLIENT" == true ]; then
  kubectl delete -f ./manifests/yamls/netAttachDef-sriov.yaml
fi

del_labels

if [ "$CLEAN_ALL" == true ]; then
  rm -rf manifests/yamls/*.yaml
  rm -rf iperf-logs/*.txt
  rm -rf ovn-traces/*.txt
fi
