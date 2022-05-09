#!/bin/bash

#
# Default values (possible to override)
#

FT_REQ_REMOTE_CLIENT_NODE=${FT_REQ_REMOTE_CLIENT_NODE:-first}
FT_REQ_SERVER_NODE=${FT_REQ_SERVER_NODE:-all}
FT_SRIOV_NODE_LABEL=${FT_SRIOV_NODE_LABEL:-network.operator.openshift.io/external-openvswitch}
FT_CLIENT_CPU_MASK=${FT_CLIENT_CPU_MASK:-}

# Deployment Variations
FT_HOSTONLY=${FT_HOSTONLY:-unknown}
FT_NAMESPACE=${FT_NAMESPACE:-default}
# Multi-Cluster Control
FT_CLIENTONLY=${FT_CLIENTONLY:-unknown}
FT_EXPORT_SVC=${FT_EXPORT_SVC:-false}
FT_SVC_QUALIFIER=${FT_SVC_QUALIFIER:-}
FT_MC_NAMESPACE=${FT_MC_NAMESPACE:-submariner-operator}
FT_MC_CO_SERVER_LABEL=${FT_MC_CO_SERVER_LABEL:-submariner.io/gateway=true}


# Launch specific variables
NET_ATTACH_DEF_NAME=${NET_ATTACH_DEF_NAME:-ftnetattach}
SRIOV_RESOURCE_NAME=${SRIOV_RESOURCE_NAME:-openshift.io/mlnx_bf}
TEST_IMAGE=${TEST_IMAGE:-quay.io/billy99/ft-base-image:0.9}


# Clean specific variables
CLEAN_ALL=${CLEAN_ALL:-false}


# Test specific variables
TEST_CASE=${TEST_CASE:-0}
VERBOSE=${VERBOSE:-false}
FT_VARS=${FT_VARS:-false}
FT_NOTES=${FT_NOTES:-true}
FT_DEBUG=${FT_DEBUG:-false}
# curl Control
CURL=${CURL:-true}
CURL_CMD=${CURL_CMD:-curl -m 5}
# iPerf Control
IPERF=${IPERF:-false}
IPERF_CMD=${IPERF_CMD:-iperf3}
IPERF_TIME=${IPERF_TIME:-10}
# Trace Control
OVN_TRACE=${OVN_TRACE:-false}
OVN_TRACE_CMD=${OVN_TRACE_CMD:-./ovnkube-trace -loglevel=5 -tcp}
OVN_K_NAMESPACE=${OVN_K_NAMESPACE:-"ovn-kubernetes"}
SSL_ENABLE=${SSL_ENABLE:-"-noSSL"}
# External Access
EXTERNAL_IP=${EXTERNAL_IP:-8.8.8.8}
EXTERNAL_URL=${EXTERNAL_URL:-google.com}


# From YAML Files
CLIENT_POD_NAME_PREFIX=${CLIENT_POD_NAME_PREFIX:-ft-client-pod}
CLIENT_HOST_POD_NAME_PREFIX=${CLIENT_HOST_POD_NAME_PREFIX:-ft-client-pod-host}

FT_TOOLS_POD_NAME=${FT_TOOLS_POD_NAME:-ft-tools}

HTTP_SERVER_POD_NAME=${HTTP_SERVER_POD_NAME:-ft-http-server-pod-v4}
HTTP_SERVER_HOST_POD_NAME=${HTTP_SERVER_HOST_POD_NAME:-ft-http-server-host-v4}

HTTP_CLUSTERIP_POD_SVC_NAME=${HTTP_CLUSTERIP_POD_SVC_NAME:-ft-http-service-clusterip-pod-v4}
HTTP_CLUSTERIP_HOST_SVC_NAME=${HTTP_CLUSTERIP_HOST_SVC_NAME:-ft-http-service-clusterip-host-v4}

HTTP_NODEPORT_SVC_NAME=${HTTP_NODEPORT_SVC_NAME:-ft-http-service-nodeport-pod-v4}
HTTP_NODEPORT_HOST_SVC_NAME=${HTTP_NODEPORT_HOST_SVC_NAME:-ft-http-service-nodeport-host-v4}

HTTP_CLUSTERIP_POD_SVC_PORT=${HTTP_CLUSTERIP_POD_SVC_PORT:-8080}
HTTP_CLUSTERIP_HOST_SVC_PORT=${HTTP_CLUSTERIP_HOST_SVC_PORT:-8079}

HTTP_NODEPORT_POD_SVC_PORT=${HTTP_NODEPORT_POD_SVC_PORT:-30080}
HTTP_NODEPORT_HOST_SVC_PORT=${HTTP_NODEPORT_HOST_SVC_PORT:-30079}


HTTP_CLUSTERIP_KUBEAPI_SVC_NAME=${HTTP_CLUSTERIP_KUBEAPI_SVC_NAME:-kubernetes.default.svc}
HTTP_CLUSTERIP_KUBEAPI_SVC_PORT=${HTTP_CLUSTERIP_KUBEAPI_SVC_PORT:-443}
HTTP_CLUSTERIP_KUBEAPI_EP_PORT=${HTTP_CLUSTERIP_KUBEAPI_EP_PORT:-6443}


IPERF_SERVER_POD_NAME=${IPERF_SERVER_POD_NAME:-ft-iperf-server-pod-v4}
IPERF_SERVER_HOST_POD_NAME=${IPERF_SERVER_HOST_POD_NAME:-ft-iperf-server-host-v4}

IPERF_CLUSTERIP_POD_SVC_NAME=${IPERF_CLUSTERIP_POD_SVC_NAME:-ft-iperf-service-clusterip-pod-v4}
IPERF_CLUSTERIP_HOST_SVC_NAME=${IPERF_CLUSTERIP_HOST_SVC_NAME:-ft-iperf-service-clusterip-host-v4}

IPERF_NODEPORT_POD_SVC_NAME=${IPERF_NODEPORT_POD_SVC_NAME:-ft-iperf-service-nodeport-pod-v4}
IPERF_NODEPORT_HOST_SVC_NAME=${IPERF_NODEPORT_HOST_SVC_NAME:-ft-iperf-service-nodeport-host-v4}

IPERF_CLUSTERIP_POD_SVC_PORT=${IPERF_CLUSTERIP_POD_SVC_PORT:-5201}
IPERF_CLUSTERIP_HOST_SVC_PORT=${IPERF_CLUSTERIP_HOST_SVC_PORT:-5202}

IPERF_NODEPORT_POD_SVC_PORT=${IPERF_NODEPORT_POD_SVC_PORT:-30201}
IPERF_NODEPORT_HOST_SVC_PORT=${IPERF_NODEPORT_HOST_SVC_PORT:-30202}


SERVER_PATH=${SERVER_PATH:-"/etc/httpserver/"}
POD_SERVER_STRING=${POD_SERVER_STRING:-"Server - Pod Backend Reached"}
HOST_SERVER_STRING=${HOST_SERVER_STRING:-"Server - Host Backend Reached"}
EXTERNAL_SERVER_STRING=${EXTERNAL_SERVER_STRING:-"The document has moved"}
KUBEAPI_SERVER_STRING=${KUBEAPI_SERVER_STRING:-"serverAddressByClientCIDRs"}


# Local Variables not intended to be overwritten
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
IPERF_LOGS_DIR="iperf-logs"
OVN_TRACE_LOGS_DIR="ovn-traces"

LOCAL_CLIENT_NODE=
LOCAL_CLIENT_POD=
LOCAL_CLIENT_HOST_POD=
REMOTE_CLIENT_NODE_LIST=()
REMOTE_CLIENT_POD_LIST=()
REMOTE_CLIENT_HOST_POD_LIST=()

FT_SERVER_NODE_LABEL=ft.ServerPod
FT_CLIENT_NODE_LABEL=ft.ClientPod

HTTP_SERVER_POD_IP=
IPERF_SERVER_POD_IP=

HTTP_CLUSTERIP_HOST_SVC_IPV4_LIST=()
HTTP_CLUSTERIP_HOST_SVC_CLUSTER_LIST=()

IPERF_CLUSTERIP_HOST_SVC_IPV4_LIST=()
IPERF_CLUSTERIP_HOST_SVC_CLUSTER_LIST=()

HTTP_CLUSTERIP_POD_SVC_IPV4_LIST=()
HTTP_CLUSTERIP_POD_SVC_CLUSTER_LIST=()

IPERF_CLUSTERIP_POD_SVC_IPV4_LIST=()
IPERF_CLUSTERIP_POD_SVC_CLUSTER_LIST=()

HTTP_NODEPORT_POD_SVC_IPV4_LIST=()
HTTP_NODEPORT_POD_SVC_CLUSTER_LIST=()

HTTP_NODEPORT_HOST_SVC_IPV4_LIST=()
HTTP_NODEPORT_HOST_SVC_CLUSTER_LIST=()

IPERF_NODEPORT_POD_SVC_IPV4_LIST=()
IPERF_NODEPORT_POD_SVC_CLUSTER_LIST=()

IPERF_NODEPORT_HOST_SVC_IPV4_LIST=()
IPERF_NODEPORT_HOST_SVC_CLUSTER_LIST=()

MY_CLUSTER=
SVCNAME_CLUSTER=
SERVER_NODE=

UNKNOWN="Unknown"
EXTERNAL="External"
REMOTE="Remote"

dump-working-data() {
  echo
  echo "Default/Override Values:"
  echo "  Launch Control:"
  echo "    FT_HOSTONLY                        $FT_HOSTONLY"
  echo "    FT_CLIENTONLY                      $FT_CLIENTONLY"
  echo "    FT_NAMESPACE                       $FT_NAMESPACE"
  echo "    FT_REQ_SERVER_NODE                 $FT_REQ_SERVER_NODE"
  echo "    FT_REQ_REMOTE_CLIENT_NODE          $FT_REQ_REMOTE_CLIENT_NODE"
  echo "    FT_SRIOV_NODE_LABEL                $FT_SRIOV_NODE_LABEL"
  echo "    FT_EXPORT_SVC                      $FT_EXPORT_SVC"
if [ ${COMMAND} == "cleanup" ] ; then
  echo "    HTTP_SERVER_POD_NAME               $HTTP_SERVER_POD_NAME"
  echo "    HTTP_SERVER_HOST_POD_NAME          $HTTP_SERVER_HOST_POD_NAME"
  echo "    CLEAN_ALL                          $CLEAN_ALL"
fi
  echo "  Label Management:"
  echo "    FT_SERVER_NODE_LABEL               $FT_SERVER_NODE_LABEL"
  echo "    FT_CLIENT_NODE_LABEL               $FT_CLIENT_NODE_LABEL"
if [ ${COMMAND} == "test" ] ; then
  echo "  Test Control:"
  echo "    TEST_CASE (0 means all)            $TEST_CASE"
  echo "    VERBOSE                            $VERBOSE"
  echo "    FT_VARS                            $FT_VARS"
  echo "    FT_NOTES                           $FT_NOTES"
  echo "    FT_DEBUG                           $FT_DEBUG"
  echo "    CURL                               $CURL"
  echo "    CURL_CMD                           $CURL_CMD"
  echo "    IPERF                              $IPERF"
  echo "    IPERF_CMD                          $IPERF_CMD"
  echo "    IPERF_TIME                         $IPERF_TIME"
  echo "    FT_CLIENT_CPU_MASK                 $FT_CLIENT_CPU_MASK"
  echo "    OVN_TRACE                          $OVN_TRACE"
  echo "    OVN_TRACE_CMD                      $OVN_TRACE_CMD"
  echo "    FT_SVC_QUALIFIER                   $FT_SVC_QUALIFIER"
  echo "    FT_MC_NAMESPACE                    $FT_MC_NAMESPACE"
  echo "    FT_MC_CO_SERVER_LABEL              $FT_MC_CO_SERVER_LABEL"
  echo "  OVN Trace Control:"
  echo "    OVN_K_NAMESPACE                    $OVN_K_NAMESPACE"
  echo "    SSL_ENABLE                         $SSL_ENABLE"
fi
if [ ${COMMAND} == "launch" ] || [ ${COMMAND} == "test" ] ; then
  echo "  From YAML Files:"
  echo "    NET_ATTACH_DEF_NAME                $NET_ATTACH_DEF_NAME"
  echo "    SRIOV_RESOURCE_NAME                $SRIOV_RESOURCE_NAME"
  echo "    TEST_IMAGE                         $TEST_IMAGE"
  echo "    CLIENT_POD_NAME_PREFIX             $CLIENT_POD_NAME_PREFIX"
  echo "    http Server:"
  echo "      HTTP_SERVER_POD_NAME             $HTTP_SERVER_POD_NAME"
  echo "      HTTP_SERVER_HOST_POD_NAME        $HTTP_SERVER_HOST_POD_NAME"
  echo "      HTTP_CLUSTERIP_POD_SVC_NAME      $HTTP_CLUSTERIP_POD_SVC_NAME"
  echo "      HTTP_CLUSTERIP_POD_SVC_PORT      $HTTP_CLUSTERIP_POD_SVC_PORT"
  echo "      HTTP_CLUSTERIP_HOST_SVC_NAME     $HTTP_CLUSTERIP_HOST_SVC_NAME"
  echo "      HTTP_CLUSTERIP_HOST_SVC_PORT     $HTTP_CLUSTERIP_HOST_SVC_PORT"
  echo "      HTTP_NODEPORT_SVC_NAME           $HTTP_NODEPORT_SVC_NAME"
  echo "      HTTP_NODEPORT_POD_SVC_PORT       $HTTP_NODEPORT_POD_SVC_PORT"
  echo "      HTTP_NODEPORT_HOST_SVC_NAME      $HTTP_NODEPORT_HOST_SVC_NAME"
  echo "      HTTP_NODEPORT_HOST_SVC_PORT      $HTTP_NODEPORT_HOST_SVC_PORT"
  echo "    iperf Server:"
  echo "      IPERF_SERVER_POD_NAME            $IPERF_SERVER_POD_NAME"
  echo "      IPERF_SERVER_HOST_POD_NAME       $IPERF_SERVER_HOST_POD_NAME"
  echo "      IPERF_CLUSTERIP_POD_SVC_NAME     $IPERF_CLUSTERIP_POD_SVC_NAME"
  echo "      IPERF_CLUSTERIP_POD_SVC_PORT     $IPERF_CLUSTERIP_POD_SVC_PORT"
  echo "      IPERF_CLUSTERIP_HOST_SVC_NAME    $IPERF_CLUSTERIP_HOST_SVC_NAME"
  echo "      IPERF_CLUSTERIP_HOST_SVC_PORT    $IPERF_CLUSTERIP_HOST_SVC_PORT"
  echo "      IPERF_NODEPORT_POD_SVC_NAME      $IPERF_NODEPORT_POD_SVC_NAME"
  echo "      IPERF_NODEPORT_POD_SVC_PORT      $IPERF_NODEPORT_POD_SVC_PORT"
  echo "      IPERF_NODEPORT_HOST_SVC_NAME     $IPERF_NODEPORT_HOST_SVC_NAME"
  echo "      IPERF_NODEPORT_HOST_SVC_PORT     $IPERF_NODEPORT_HOST_SVC_PORT"
fi
if [ ${COMMAND} == "test" ] ; then
  echo "    SERVER_PATH                        $SERVER_PATH"
  echo "    POD_SERVER_STRING                  $POD_SERVER_STRING"
  echo "    HOST_SERVER_STRING                 $HOST_SERVER_STRING"
  echo "    EXTERNAL_SERVER_STRING             $EXTERNAL_SERVER_STRING"
  echo "    KUBEAPI_SERVER_STRING              $KUBEAPI_SERVER_STRING"
  echo "  External Access:"
  echo "    EXTERNAL_IP                        $EXTERNAL_IP"
  echo "    EXTERNAL_URL                       $EXTERNAL_URL"
  echo "Queried Values:"
  echo "  Pod Backed:"
  echo "    HTTP_SERVER_POD_IP                 $HTTP_SERVER_POD_IP"
  echo "    IPERF_SERVER_POD_IP                $IPERF_SERVER_POD_IP"
  echo "    SERVER_POD_NODE                    $SERVER_POD_NODE"
  echo "    LOCAL_CLIENT_NODE                  $LOCAL_CLIENT_NODE"
  echo "    LOCAL_CLIENT_POD                   $LOCAL_CLIENT_POD"
  echo "    REMOTE_CLIENT_NODE_LIST            $REMOTE_CLIENT_NODE_LIST"
  echo "    REMOTE_CLIENT_POD_LIST             $REMOTE_CLIENT_POD_LIST"
  echo "    HTTP_CLUSTERIP_POD_SVC_IPV4_LIST   $HTTP_CLUSTERIP_POD_SVC_IPV4_LIST"
  echo "    HTTP_CLUSTERIP_POD_SVC_PORT        $HTTP_CLUSTERIP_POD_SVC_PORT"
  echo "    HTTP_NODEPORT_POD_SVC_IPV4_LIST    $HTTP_NODEPORT_POD_SVC_IPV4_LIST"
  echo "    HTTP_NODEPORT_POD_SVC_PORT         $HTTP_NODEPORT_POD_SVC_PORT"
  echo "    IPERF_CLUSTERIP_POD_SVC_IPV4_LIST  $IPERF_CLUSTERIP_POD_SVC_IPV4_LIST"
  echo "    IPERF_CLUSTERIP_POD_SVC_PORT       $IPERF_CLUSTERIP_POD_SVC_PORT"
  echo "    IPERF_NODEPORT_POD_SVC_IPV4_LIST   $IPERF_NODEPORT_POD_SVC_IPV4_LIST"
  echo "    IPERF_NODEPORT_POD_SVC_PORT        $IPERF_NODEPORT_POD_SVC_PORT"
  echo "  Host backed:"
  echo "    HTTP_SERVER_HOST_IP                $HTTP_SERVER_HOST_IP"
  echo "    IPERF_SERVER_HOST_IP               $IPERF_SERVER_HOST_IP"
  echo "    SERVER_HOST_NODE                   $SERVER_POD_NODE"
  echo "    LOCAL_CLIENT_HOST_NODE             $LOCAL_CLIENT_NODE"
  echo "    LOCAL_CLIENT_HOST_POD              $LOCAL_CLIENT_HOST_POD"
  echo "    REMOTE_CLIENT_HOST_NODE_LIST       $REMOTE_CLIENT_NODE_LIST"
  echo "    REMOTE_CLIENT_HOST_POD_LIST        $REMOTE_CLIENT_HOST_POD_LIST"
  echo "    HTTP_CLUSTERIP_HOST_SVC_IPV4_LIST  $HTTP_CLUSTERIP_HOST_SVC_IPV4_LIST"
  echo "    HTTP_CLUSTERIP_HOST_SVC_PORT       $HTTP_CLUSTERIP_HOST_SVC_PORT"
  echo "    HTTP_NODEPORT_HOST_SVC_IPV4_LIST   $HTTP_NODEPORT_HOST_SVC_IPV4_LIST"
  echo "    HTTP_NODEPORT_HOST_SVC_PORT        $HTTP_NODEPORT_HOST_SVC_PORT"
  echo "    IPERF_CLUSTERIP_HOST_SVC_IPV4_LIST $IPERF_CLUSTERIP_HOST_SVC_IPV4_LIST"
  echo "    IPERF_CLUSTERIP_HOST_SVC_PORT      $IPERF_CLUSTERIP_HOST_SVC_PORT"
  echo "    IPERF_NODEPORT_HOST_SVC_IPV4_LIST  $IPERF_NODEPORT_HOST_SVC_IPV4_LIST"
  echo "    IPERF_NODEPORT_HOST_SVC_PORT       $IPERF_NODEPORT_HOST_SVC_PORT"
  echo "  Kubernetes API:"
  echo "    HTTP_CLUSTERIP_KUBEAPI_SVC_IPV4    $HTTP_CLUSTERIP_KUBEAPI_SVC_IPV4"
  echo "    HTTP_CLUSTERIP_KUBEAPI_SVC_PORT    $HTTP_CLUSTERIP_KUBEAPI_SVC_PORT"
  echo "    HTTP_CLUSTERIP_KUBEAPI_EP_IP       $HTTP_CLUSTERIP_KUBEAPI_EP_IP"
  echo "    HTTP_CLUSTERIP_KUBEAPI_EP_PORT     $HTTP_CLUSTERIP_KUBEAPI_EP_PORT"
  echo "    HTTP_CLUSTERIP_KUBEAPI_SVC_NAME    $HTTP_CLUSTERIP_KUBEAPI_SVC_NAME"
fi
  echo
}


# Test for '--help'
process-help() {
  if [ ! -z "$1" ] ; then
    if [ "$1" == help ] || [ "$1" == "--help" ] ; then
      echo
      echo "This script uses ENV Variables to control test. Here are few key ones:"
      if [ ${COMMAND} == "launch" ] ; then
      echo "  FT_REQ_SERVER_NODE         - Node to run server pods on. Must be set before launching"
      echo "                               pods. Example:"
      echo "                                 FT_REQ_SERVER_NODE=ovn-worker3 ./launch.sh"
      echo "  FT_REQ_REMOTE_CLIENT_NODE  - Node to use when sending from client pod on different node"
      echo "                               from server. Example:"
      echo "                                 FT_REQ_REMOTE_CLIENT_NODE=ovn-worker4 ./test.sh"
      echo "  FT_SRIOV_NODE_LABEL        - SR-IOV is not easy to detect. If Server or Client pods need"
      echo "                               SR-IOV VFs to work, add a label to each node supporting SR-IOV"
      echo "                               and provide the label here. Default value is what is used"
      echo "                               by OpenShift to mark a SmartNIC."
      echo "                               Default: network.operator.openshift.io/external-openvswitch"
      echo "                               Example:"
      echo "                                 FT_SRIOV_NODE_LABEL=sriov-node ./launch.sh"
      echo "  SRIOV_RESOURCE_NAME        - launch.sh does not touch SR-IOV Device Plugin. If a node supports"
      echo "                               SR-IOV VFs, use this field to pass in the \"resourceName\" to be"
      echo "                               used in the NetworkAttachmentDefinition. Default: openshift.io/mlnx_bf"
      echo "                               Example:"
      echo "                                 SRIOV_RESOURCE_NAME=sriov_a ./launch.sh"
      fi
      if [ ${COMMAND} == "launch" ] || [ ${COMMAND} == "cleanup" ] ; then
      echo "  FT_HOSTONLY                - Only host network backed pods are launched, off by default."
      echo "                               Used on DPUs. It is best to export this variable. test.sh and"
      echo "                               cleanup.sh will try to detect if it was used on launch, but"
      echo "                               false positives could occur if pods are renamed or server pod"
      echo "                               failed to come up. Example:"
      echo "                                 export FT_HOSTONLY=true"
      echo "                                 ./launch.sh"
      echo "                                 ./test.sh"
      echo "                                 ./cleanup.sh"
      echo "  FT_CLIENTONLY              - Only client pods are launched, no server pods or services. Off by"
      echo "                               default. Used in a Multi-Cluster deployment where server pods and"
      echo "                               services are deployed in a different cluster. It is best to export"
      echo "                               this variable. test.sh and cleanup.sh will try to detect if it was"
      echo "                               used on launch, but false positives could occur if pods are renamed"
      echo "                               or pods failed to come up. Example:"
      echo "                                 export FT_NAMESPACE=flow-test"
      echo "                                 export FT_CLIENTONLY=true"
      echo "                                 ./launch.sh"
      echo "                                 ./test.sh"
      echo "                                 ./cleanup.sh"
      fi
      if [ ${COMMAND} == "cleanup" ] ; then
      echo "  CLEAN_ALL                  - Remove all generated files (yamls from j2, iperf logs, and"
      echo "                               ovn-trace logs). Default is to leave in place. Example:"
      echo "                                 CLEAN_ALL=true ./cleanup.sh"
      fi
      if [ ${COMMAND} == "test" ] ; then
      echo "  TEST_CASE (0 means all)    - Run a single test. Example:"
      echo "                                 TEST_CASE=3 ./test.sh"
      echo "  VERBOSE                    - Command output is masked by default. Enable curl output."
      echo "                               Example:"
      echo "                                 VERBOSE=true ./test.sh"
      echo "  IPERF                      - 'iperf3' can be run on each flow, off by default. Example:"
      echo "                                 IPERF=true ./test.sh"
      echo "  OVN_TRACE                  - 'ovn-trace' can be run on each flow, off by deafult. Example:"
      echo "                                 OVN_TRACE=true ./test.sh"
      echo "  CURL_CMD                   - Curl command to run. Allows additional parameters to be"
      echo "                               inserted. Example:"
      echo "                                 CURL_CMD=\"curl -v --connect-timeout 5\" ./test.sh"
      echo "  FT_VARS                    - Print script variables. Off by default. Example:"
      echo "                                 FT_VARS=true ./test.sh"
      echo "  FT_NOTES                   - Print notes (in blue) where tests are failing but maybe shouldn't be."
      echo "                               On by default. Example:"
      echo "                                 FT_NOTES=false ./test.sh"
      echo "  FT_REQ_REMOTE_CLIENT_NODE  - Node to use when sending from client pod on different node"
      echo "                               from server. Example:"
      echo "                                 FT_REQ_REMOTE_CLIENT_NODE=ovn-worker4 ./test.sh"
      echo "  FT_CLIENT_CPU_MASK         - CPU Mask to be used to run a \"taskset\" on command being run."
      echo "                               Current on being used on \"iperf3\". Example:"
      echo "                                 FT_CLIENT_CPU_MASK=0x100 TEST_CASE=1 IPERF=true CURL=false ./test.sh"
      fi
      echo "  FT_NAMESPACE               - Namespace for all pods, configMaps and services associated with"
      echo "                               Flow Tester. Defaults to \"default\" namespace. It is best to"
      echo "                               export this variable because launch.sh and cleanup.sh also need"
      echo "                               the same value set. Example:"
      echo "                                 export FT_NAMESPACE=flow-test"
      echo "                                 ./launch.sh"
      echo "                                 ./test.sh"
      echo "                                 ./cleanup.sh"

      dump-working-data
    else
      echo
      if [ ${COMMAND} == "launch" ] ; then
      echo "Unknown input, try using \"./launch.sh --help\""
      elif [ ${COMMAND} == "test" ] ; then
      echo "Unknown input, try using \"./test.sh --help\""
      elif [ ${COMMAND} == "cleanup" ] ; then
      echo "Unknown input, try using \"./cleanup.sh --help\""
      fi
      echo
    fi

    exit 0
  fi
}

determine-default-data() {
  # Try to determine if only host-networked pods were created.
  if [ "$FT_HOSTONLY" == unknown ]; then
    if [ ${COMMAND} == "launch" ] ; then
      FT_HOSTONLY=false
    else
      # Look for Server pod, in Host Only it shouldn't be there
      TEST_HTTP_SERVER=$(kubectl get pods -n ${FT_NAMESPACE} | grep -o "$HTTP_SERVER_POD_NAME")
      if [ -z "${TEST_HTTP_SERVER}" ]; then
        # Server pod isn't there for Client Only either, so check Host Backed Server pod, it should be there
        TEST_HTTP_HOST_SERVER=$(kubectl get pods -n ${FT_NAMESPACE} | grep -o "$HTTP_SERVER_HOST_POD_NAME")
        if [ -n "${TEST_HTTP_HOST_SERVER}" ]; then
          FT_HOSTONLY=true
        else
          FT_HOSTONLY=false
        fi
      else
        FT_HOSTONLY=false
      fi
    fi
  fi

  # Try to determine if only server pods were created.
  if [ "$FT_CLIENTONLY" == unknown ]; then
    if [ ${COMMAND} == "launch" ] ; then
      FT_CLIENTONLY=false
    else
      # Look for Host backer Server pod, in Client Only it shouldn't be there
      TEST_HTTP_SERVER=$(kubectl get pods -n ${FT_NAMESPACE} | grep -o "$HTTP_SERVER_HOST_POD_NAME")
      if [ -z "${TEST_HTTP_SERVER}" ]; then
        FT_CLIENTONLY=true
      else
        FT_CLIENTONLY=false
      fi
    fi
  fi
}

query-dynamic-data() {
  MY_CLUSTER=$(kubectl config current-context)

  # In Client Only mode, no Server Pods or Services are created. They are assumed
  # to be in another cluster. So checks for FT_CLIENTONLY are needed to skip
  # any queries looking for Server Pods or Services.

  # In Host Only mode, only Host Backed Pods and Services are created. So checks for
  # FT_HOSTONLY are need to skip checks non-Host Backed Pods and Services.

  #
  # Determine Local and Remote Nodes
  #
  if [ "$FT_CLIENTONLY" == false ] ; then
    SERVER_POD_NODE=$(kubectl get pods -n ${FT_NAMESPACE} -o wide | grep $HTTP_SERVER_HOST_POD_NAME  | awk -F' ' '{print $7}')
    SVCNAME_CLUSTER=$MY_CLUSTER

    # Local Client Node is the same Node Server is running on.
    LOCAL_CLIENT_NODE=$SERVER_POD_NODE
  else
  	# In Client Only, there are no Server Nodes, so leave blank and logic below
  	# will pick the first non-Master. 
    SERVER_POD_NODE=$REMOTE
    SVCNAME_CLUSTER=$UNKNOWN

    # Leave blank and determine below.
    LOCAL_CLIENT_NODE=
  fi


  # Find the REMOTE NODE for POD and HOST POD. (REMOTE is a node server is NOT running on)
  [ "$FT_DEBUG" == true ] && echo "Determine Local and Remote Nodes:"
  NODE_ARRAY=($(kubectl get nodes --no-headers=true | awk -F' ' '{print $1}'))
  for NODE in "${NODE_ARRAY[@]}"
  do
    [ "$FT_DEBUG" == true ] && echo "  Processing NODE=${NODE}"
    # Check for non-master (KIND clusters don't have "worker" role set)
    kubectl get node ${NODE} --no-headers=true | awk -F' ' '{print $3}' | grep -q master
    if [ "$?" == 1 ]; then
      # If this node was requested and LOCAL_CLIENT_NODE is blank (because Client Only Mode
      # and there is no Server Node, which is the default), then use this node as Local Client.
      if [ "$FT_REQ_SERVER_NODE" == "${NODE}" ] && [ -z "${LOCAL_CLIENT_NODE}" ] ; then
        LOCAL_CLIENT_NODE=${NODE}
        [ "$FT_DEBUG" == true ] && echo "    LOCAL_CLIENT_NODE=${LOCAL_CLIENT_NODE} because node requested"
      # If this node was requested and REMOTE_CLIENT_NODE_LIST is blank (because Client Only Mode
      # and there is no Server Node, which is the default), then use this node as Remote Client.
      elif [ "$FT_REQ_REMOTE_CLIENT_NODE" == "${NODE}" ] && [ -z "${REMOTE_CLIENT_NODE_LIST}" ] ; then
        REMOTE_CLIENT_NODE_LIST+=(${NODE})
        [ "$FT_DEBUG" == true ] && echo "    REMOTE_CLIENT_NODE_LIST=${REMOTE_CLIENT_NODE_LIST[@]} because node requested"
      # If LOCAL_CLIENT_NODE is blank (because Client Only Mode and there is no Server Node,
      # which is the default), then use this node as Local Client.
      elif [ -z "${LOCAL_CLIENT_NODE}" ] ; then
        LOCAL_CLIENT_NODE=${NODE}
        [ "$FT_DEBUG" == true ] && echo "    LOCAL_CLIENT_NODE=${LOCAL_CLIENT_NODE} because next available"
      # Otherwise if this was the requested Remote Client or the first node requested,
      # and make sure it doesn't overlap with Server Node.
      elif [ ${#REMOTE_CLIENT_NODE_LIST[@]} -eq 0 ] && [ "$FT_REQ_REMOTE_CLIENT_NODE" == "first" ] || [ "$FT_REQ_REMOTE_CLIENT_NODE" == "${NODE}" ]; then
        if [ "$LOCAL_CLIENT_NODE" != "${NODE}" ]; then
          REMOTE_CLIENT_NODE_LIST=(${NODE})
          [ "$FT_DEBUG" == true ] && echo "    REMOTE_CLIENT_NODE_LIST=${REMOTE_CLIENT_NODE_LIST[@]} because next available and first or specific requested"
        fi
      # Otherwise if all was requested, and make sure it doesn't overlap with Server Node.
      elif [ "$FT_REQ_REMOTE_CLIENT_NODE" == "all" ]; then
        if [ "$LOCAL_CLIENT_NODE" != "${NODE}" ]; then
          REMOTE_CLIENT_NODE_LIST+=(${NODE})
          [ "$FT_DEBUG" == true ] && echo "    REMOTE_CLIENT_NODE_LIST=${REMOTE_CLIENT_NODE_LIST[@]} because all requested"
        fi
      fi
    fi
  done

  if [ "$FT_DEBUG" == true ]; then
    echo "  Summary:"
    echo "    LOCAL_CLIENT_NODE=${LOCAL_CLIENT_NODE}"
    echo "    REMOTE_CLIENT_NODE_LIST=${REMOTE_CLIENT_NODE_LIST[@]}"
    echo
  fi

  for NODE in "${REMOTE_CLIENT_NODE_LIST[@]}"
  do
    if [ "${NODE}" == "${LOCAL_CLIENT_NODE}" ]; then
      if [ "$FT_REQ_REMOTE_CLIENT_NODE" == "$NODE" ]; then
        echo -e "${BLUE}ERROR: As requested, REMOTE_CLIENT_NODE_LIST is same as LOCAL_CLIENT_NODE: $LOCAL_CLIENT_NODE${NC}\r\n"
      else
        echo -e "${RED}ERROR: Unable to find a node for REMOTE_CLIENT_NODE_LIST. Using LOCAL_CLIENT_NODE: $LOCAL_CLIENT_NODE${NC}\r\n"
      fi
    fi
  done
  
  #
  # Determine Local and Remote Pods
  #
  [ "$FT_DEBUG" == true ] && echo "Determine Local and Remote Pods:"

  LOCAL_CLIENT_HOST_POD=$(kubectl get pods -n ${FT_NAMESPACE} --selector=name=${CLIENT_HOST_POD_NAME_PREFIX} -o wide | grep -w "${LOCAL_CLIENT_NODE}" | awk -F' ' '{print $1}')
  if [ "$FT_HOSTONLY" == false ]; then
    LOCAL_CLIENT_POD=$(kubectl get pods -n ${FT_NAMESPACE} --selector=name=${CLIENT_POD_NAME_PREFIX} -o wide | grep -w "${LOCAL_CLIENT_NODE}" | awk -F' ' '{print $1}')
  else
    LOCAL_CLIENT_POD=
  fi

  for NODE in "${REMOTE_CLIENT_NODE_LIST[@]}"
  do
    REMOTE_CLIENT_HOST_POD_LIST+=($(kubectl get pods -n ${FT_NAMESPACE} --selector=name=${CLIENT_HOST_POD_NAME_PREFIX} -o wide | grep -w "${NODE}" | awk -F' ' '{print $1}'))
    if [ "$FT_HOSTONLY" == false ]; then
      REMOTE_CLIENT_POD_LIST+=($(kubectl get pods -n ${FT_NAMESPACE} --selector=name=${CLIENT_POD_NAME_PREFIX} -o wide| grep -w "${NODE}" | awk -F' ' '{print $1}'))
    fi
  done

  if [ "$FT_DEBUG" == true ]; then
    echo "  Summary:"
    echo "    LOCAL_CLIENT_HOST_POD=${LOCAL_CLIENT_HOST_POD}"
    echo "    REMOTE_CLIENT_HOST_POD_LIST=${REMOTE_CLIENT_HOST_POD_LIST[@]}"
    echo "    LOCAL_CLIENT_POD=${LOCAL_CLIENT_POD}"
    echo "    REMOTE_CLIENT_POD_LIST=${REMOTE_CLIENT_POD_LIST[@]}"
    echo
  fi

  #
  # Determine IP Addresses and Ports
  #
  if [ "$FT_CLIENTONLY" == false ] ; then
    TMP_GET_PODS_STR=$(kubectl get pods -n ${FT_NAMESPACE} -o wide)
    TMP_GET_SERVICES_STR=$(kubectl get services -n ${FT_NAMESPACE})

    HTTP_SERVER_HOST_IP=$(echo "${TMP_GET_PODS_STR}" | grep $HTTP_SERVER_HOST_POD_NAME  | awk -F' ' '{print $6}')
    IPERF_SERVER_HOST_IP=$(echo "${TMP_GET_PODS_STR}" | grep $IPERF_SERVER_HOST_POD_NAME  | awk -F' ' '{print $6}')

    HTTP_CLUSTERIP_HOST_SVC_IPV4_LIST=($(echo "${TMP_GET_SERVICES_STR}" | grep $HTTP_CLUSTERIP_HOST_SVC_NAME | awk -F' ' '{print $3}'))
    HTTP_CLUSTERIP_HOST_SVC_PORT=$(echo "${TMP_GET_SERVICES_STR}" | grep $HTTP_CLUSTERIP_HOST_SVC_NAME | awk -F' ' '{print $5}' | awk -F/ '{print $1}')
    HTTP_CLUSTERIP_HOST_SVC_CLUSTER_LIST=($MY_CLUSTER)

    HTTP_NODEPORT_HOST_SVC_IPV4_LIST=($(echo "${TMP_GET_SERVICES_STR}" | grep $HTTP_NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $3}'))
    HTTP_NODEPORT_HOST_SVC_PORT=$(echo "${TMP_GET_SERVICES_STR}" | grep $HTTP_NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $5}' | awk -F: '{print $2}' | awk -F'/' '{print $1}')
    HTTP_NODEPORT_HOST_SVC_CLUSTER_LIST=($MY_CLUSTER)

    IPERF_CLUSTERIP_HOST_SVC_IPV4_LIST=($(echo "${TMP_GET_SERVICES_STR}" | grep $IPERF_CLUSTERIP_HOST_SVC_NAME | awk -F' ' '{print $3}'))
    IPERF_CLUSTERIP_HOST_SVC_PORT=$(echo "${TMP_GET_SERVICES_STR}" | grep $IPERF_CLUSTERIP_HOST_SVC_NAME | awk -F' ' '{print $5}' | awk -F'/' '{print $1}')
    IPERF_CLUSTERIP_HOST_SVC_CLUSTER_LIST=($MY_CLUSTER)

    IPERF_NODEPORT_HOST_SVC_IPV4_LIST=($(echo "${TMP_GET_SERVICES_STR}" | grep $IPERF_NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $3}'))
    IPERF_NODEPORT_HOST_SVC_PORT=$(echo "${TMP_GET_SERVICES_STR}" | grep $IPERF_NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $5}' | awk -F: '{print $2}' | awk -F'/' '{print $1}')
    IPERF_NODEPORT_HOST_SVC_CLUSTER_LIST=($MY_CLUSTER)

    if [ "$FT_HOSTONLY" == false ]; then
      HTTP_SERVER_POD_IP=$(echo "${TMP_GET_PODS_STR}" | grep $HTTP_SERVER_POD_NAME  | awk -F' ' '{print $6}')
      IPERF_SERVER_POD_IP=$(echo "${TMP_GET_PODS_STR}" | grep $IPERF_SERVER_POD_NAME  | awk -F' ' '{print $6}')

      HTTP_CLUSTERIP_POD_SVC_IPV4_LIST=($(echo "${TMP_GET_SERVICES_STR}" | grep $HTTP_CLUSTERIP_POD_SVC_NAME | awk -F' ' '{print $3}'))
      HTTP_CLUSTERIP_POD_SVC_PORT=$(echo "${TMP_GET_SERVICES_STR}" | grep $HTTP_CLUSTERIP_POD_SVC_NAME | awk -F' ' '{print $5}' | awk -F/ '{print $1}')
      HTTP_CLUSTERIP_POD_SVC_CLUSTER_LIST=($MY_CLUSTER)

      HTTP_NODEPORT_POD_SVC_IPV4_LIST=($(echo "${TMP_GET_SERVICES_STR}" | grep $HTTP_NODEPORT_SVC_NAME | awk -F' ' '{print $3}'))
      HTTP_NODEPORT_POD_SVC_PORT=$(echo "${TMP_GET_SERVICES_STR}" | grep $HTTP_NODEPORT_SVC_NAME | awk -F' ' '{print $5}' | awk -F: '{print $2}' | awk -F'/' '{print $1}')
      HTTP_NODEPORT_POD_SVC_CLUSTER_LIST=($MY_CLUSTER)

      IPERF_CLUSTERIP_POD_SVC_IPV4_LIST=($(echo "${TMP_GET_SERVICES_STR}" | grep $IPERF_CLUSTERIP_POD_SVC_NAME | awk -F' ' '{print $3}'))
      IPERF_CLUSTERIP_POD_SVC_PORT=$(echo "${TMP_GET_SERVICES_STR}" | grep $IPERF_CLUSTERIP_POD_SVC_NAME | awk -F' ' '{print $5}' | awk -F'/' '{print $1}')
      IPERF_CLUSTERIP_POD_SVC_CLUSTER_LIST=($MY_CLUSTER)

      IPERF_NODEPORT_POD_SVC_IPV4_LIST=($(echo "${TMP_GET_SERVICES_STR}" | grep $IPERF_NODEPORT_POD_SVC_NAME | awk -F' ' '{print $3}'))
      IPERF_NODEPORT_POD_SVC_PORT=$(echo "${TMP_GET_SERVICES_STR}" | grep $IPERF_NODEPORT_POD_SVC_NAME | awk -F' ' '{print $5}' | awk -F: '{print $2}' | awk -F'/' '{print $1}')
      IPERF_NODEPORT_POD_SVC_CLUSTER_LIST=($MY_CLUSTER)
    fi
  else
    # Client Only is true, so no Server Pods and Services are imported.
    #
    # $ kubectl get serviceimports --no-headers=true -n submariner-operator
    # ft-http-service-clusterip-host-v4-flow-test-cluster1    ClusterSetIP   ["100.1.95.195"]    20h
    # ft-http-service-clusterip-host-v4-flow-test-cluster3    ClusterSetIP   ["100.3.250.32"]    20h
    # ft-http-service-clusterip-pod-v4-flow-test-cluster1     ClusterSetIP   ["100.1.106.17"]    20h
    # ft-http-service-clusterip-pod-v4-flow-test-cluster3     ClusterSetIP   ["100.3.52.117"]    20h
    # ft-iperf-service-clusterip-host-v4-flow-test-cluster1   ClusterSetIP   ["100.1.194.210"]   20h
    # ft-iperf-service-clusterip-host-v4-flow-test-cluster3   ClusterSetIP   ["100.3.115.202"]   20h
    # ft-iperf-service-clusterip-pod-v4-flow-test-cluster1    ClusterSetIP   ["100.1.8.236"]     20h
    # ft-iperf-service-clusterip-pod-v4-flow-test-cluster3    ClusterSetIP   ["100.3.147.75"]    20h
    #
    # TMP_SVC_NAME
    #   grep for the SVC_NAME (sub-string),
    #   use awk to tokenize row delimiting on space and retrieve full NAME,
    # IP Address
    #   grep for the TMP_SVC_NAME,
    #   use awk to tokenize row delimiting on space and retrieve IP Token,
    #   use awk to tokenize IP string delimiting on " and getting IP Address without [""]

    TMP_SVC_IMPORTS=$(kubectl get serviceimports --no-headers=true -n ${FT_MC_NAMESPACE})
    if [[ ! -z "$TMP_SVC_IMPORTS" ]] ; then
      [ "$FT_DEBUG" == true ] && echo "Determine Client-Only Service Import Values:"

      # There can be multiple Clusters to send to. Loop through each service name prefix
      # (like "ft-http-service-clusterip-pod-v4"), then process each service that matches.

      TMP_SVC_NAME_LIST=( $(echo "${TMP_SVC_IMPORTS}" | grep ${HTTP_CLUSTERIP_HOST_SVC_NAME} | awk -F' ' '{print $1}') )
      for SVC_NAME in "${TMP_SVC_NAME_LIST[@]}"
      do
        HTTP_CLUSTERIP_HOST_SVC_IPV4_LIST+=($(echo "${TMP_SVC_IMPORTS}" | grep ${SVC_NAME} | awk -F' ' '{print $3}' | awk -F\" '{print $2}'))
        HTTP_CLUSTERIP_HOST_SVC_PORT=$(kubectl get serviceimports -n ${FT_MC_NAMESPACE} -o jsonpath='{.spec.ports[0].port}' ${SVC_NAME})
        HTTP_CLUSTERIP_HOST_SVC_CLUSTER_LIST+=(${SVC_NAME#"${HTTP_CLUSTERIP_HOST_SVC_NAME}-${FT_NAMESPACE}-"})
      done

      TMP_SVC_NAME_LIST=( $(echo "${TMP_SVC_IMPORTS}" | grep ${IPERF_CLUSTERIP_HOST_SVC_NAME} | awk -F' ' '{print $1}') )
      for SVC_NAME in "${TMP_SVC_NAME_LIST[@]}"
      do
        IPERF_CLUSTERIP_HOST_SVC_IPV4_LIST+=($(echo "${TMP_SVC_IMPORTS}" | grep ${SVC_NAME} | awk -F' ' '{print $3}' | awk -F\" '{print $2}'))
        IPERF_CLUSTERIP_HOST_SVC_PORT=$(kubectl get serviceimports -n ${FT_MC_NAMESPACE} -o jsonpath='{.spec.ports[0].port}' ${SVC_NAME})
        IPERF_CLUSTERIP_HOST_SVC_CLUSTER_LIST+=(${SVC_NAME#"${IPERF_CLUSTERIP_HOST_SVC_NAME}-${FT_NAMESPACE}-"})
      done

      if [ "$FT_HOSTONLY" == false ]; then
        TMP_SVC_NAME_LIST=( $(echo "${TMP_SVC_IMPORTS}" | grep ${HTTP_CLUSTERIP_POD_SVC_NAME} | awk -F' ' '{print $1}') )
        for SVC_NAME in "${TMP_SVC_NAME_LIST[@]}"
        do
          HTTP_CLUSTERIP_POD_SVC_IPV4_LIST+=($(echo "${TMP_SVC_IMPORTS}" | grep ${SVC_NAME} | awk -F' ' '{print $3}' | awk -F\" '{print $2}'))
          HTTP_CLUSTERIP_POD_SVC_PORT=$(kubectl get serviceimports -n ${FT_MC_NAMESPACE} -o jsonpath='{.spec.ports[0].port}' ${SVC_NAME})
          HTTP_CLUSTERIP_POD_SVC_CLUSTER_LIST+=(${SVC_NAME#"${HTTP_CLUSTERIP_POD_SVC_NAME}-${FT_NAMESPACE}-"})
        done

        TMP_SVC_NAME_LIST=( $(echo "${TMP_SVC_IMPORTS}" | grep ${IPERF_CLUSTERIP_POD_SVC_NAME} | awk -F' ' '{print $1}') )
        for SVC_NAME in "${TMP_SVC_NAME_LIST[@]}"
        do
          IPERF_CLUSTERIP_POD_SVC_IPV4_LIST+=($(echo "${TMP_SVC_IMPORTS}" | grep ${SVC_NAME} | awk -F' ' '{print $3}' | awk -F\" '{print $2}'))
          IPERF_CLUSTERIP_POD_SVC_PORT=$(kubectl get serviceimports -n ${FT_MC_NAMESPACE} -o jsonpath='{.spec.ports[0].port}' ${SVC_NAME})
          IPERF_CLUSTERIP_POD_SVC_CLUSTER_LIST+=(${SVC_NAME#"${IPERF_CLUSTERIP_POD_SVC_NAME}-${FT_NAMESPACE}-"})
        done
      fi
    else
      echo "NO ServiceImports Detected"
    fi
  fi

  if [ "$FT_DEBUG" == true ]; then
    echo "  Summary:"
    echo "    HTTP_SERVER_HOST_IP=${HTTP_SERVER_HOST_IP}"
    echo "    HTTP_CLUSTERIP_HOST_SVC_IPV4_LIST=${HTTP_CLUSTERIP_HOST_SVC_IPV4_LIST[@]}"
    echo "    HTTP_CLUSTERIP_HOST_SVC_PORT=${HTTP_CLUSTERIP_HOST_SVC_PORT}"
    echo "    HTTP_CLUSTERIP_HOST_CLUSTER_IPV4_LIST=${HTTP_CLUSTERIP_HOST_SVC_CLUSTER_LIST[@]}"
    echo "    HTTP_NODEPORT_HOST_SVC_IPV4_LIST=${HTTP_NODEPORT_HOST_SVC_IPV4_LIST[@]}"
    echo "    HTTP_NODEPORT_HOST_SVC_PORT=${HTTP_NODEPORT_HOST_SVC_PORT}"
    echo "    HTTP_NODEPORT_HOST_SVC_CLUSTER_LIST=${HTTP_NODEPORT_HOST_CLUSTER_IPV4_LIST[@]}"
    echo "    HTTP_SERVER_POD_IP=${HTTP_SERVER_POD_IP}"
    echo "    HTTP_CLUSTERIP_POD_SVC_IPV4_LIST=${HTTP_CLUSTERIP_POD_SVC_IPV4_LIST[@]}"
    echo "    HTTP_CLUSTERIP_POD_SVC_PORT=${HTTP_CLUSTERIP_POD_SVC_PORT}"
    echo "    HTTP_CLUSTERIP_POD_SVC_CLUSTER_LIST=${HTTP_CLUSTERIP_POD_SVC_CLUSTER_LIST[@]}"
    echo "    HTTP_NODEPORT_POD_SVC_IPV4_LIST=${HTTP_NODEPORT_POD_SVC_IPV4_LIST[@]}"
    echo "    HTTP_NODEPORT_POD_SVC_PORT=${HTTP_NODEPORT_POD_SVC_PORT}"
    echo "    HTTP_NODEPORT_POD_SVC_CLUSTER_LIST=${HTTP_NODEPORT_POD_SVC_CLUSTER_LIST[@]}"
    echo "    IPERF_SERVER_HOST_IP=${IPERF_SERVER_HOST_IP}"
    echo "    IPERF_CLUSTERIP_HOST_SVC_IPV4_LIST=${IPERF_CLUSTERIP_HOST_SVC_IPV4_LIST[@]}"
    echo "    IPERF_CLUSTERIP_HOST_SVC_PORT=${IPERF_CLUSTERIP_HOST_SVC_PORT}"
    echo "    IPERF_CLUSTERIP_HOST_SVC_CLUSTER_LIST=${IPERF_CLUSTERIP_HOST_SVC_CLUSTER_LIST[@]}"
    echo "    IPERF_NODEPORT_HOST_SVC_IPV4_LIST=${IPERF_NODEPORT_HOST_SVC_IPV4_LIST[@]}"
    echo "    IPERF_NODEPORT_HOST_SVC_PORT=${IPERF_NODEPORT_HOST_SVC_PORT}"
    echo "    IPERF_NODEPORT_HOST_SVC_CLUSTER_LIST=${IPERF_NODEPORT_HOST_SVC_CLUSTER_LIST[@]}"
    echo "    IPERF_SERVER_POD_IP=${IPERF_SERVER_POD_IP}"
    echo "    IPERF_CLUSTERIP_POD_SVC_IPV4_LIST=${IPERF_CLUSTERIP_POD_SVC_IPV4_LIST[@]}"
    echo "    IPERF_CLUSTERIP_POD_SVC_PORT=${IPERF_CLUSTERIP_POD_SVC_PORT}"
    echo "    IPERF_CLUSTERIP_POD_SVC_CLUSTER_LIST=${IPERF_CLUSTERIP_POD_SVC_CLUSTER_LIST[@]}"
    echo "    IPERF_NODEPORT_POD_SVC_IPV4_LIST=${IPERF_NODEPORT_POD_SVC_IPV4_LIST[@]}"
    echo "    IPERF_NODEPORT_POD_SVC_PORT=${IPERF_NODEPORT_POD_SVC_PORT}"
    echo "    IPERF_NODEPORT_POD_SVC_CLUSTER_LIST=${IPERF_NODEPORT_POD_SVC_CLUSTER_LIST[@]}"
    echo
  fi

  # Get Kubernetes API Server Data
  TMP_STR=$(kubectl get services --no-headers kubernetes)
  HTTP_CLUSTERIP_KUBEAPI_SVC_IPV4=$(echo "${TMP_STR}" | awk -F' ' '{print $3}')
  HTTP_CLUSTERIP_KUBEAPI_SVC_PORT=$(echo "${TMP_STR}" | awk -F' ' '{print $5}' | awk -F/ '{print $1}')

  # Returns something like:
  #   "kubernetes 192.168.111.20:6443,192.168.111.21:6443,192.168.111.22:6443 7d11h"
  # Pull pull the IP and Port from the first entry
  TMP_STR=$(kubectl get endpoints --no-headers kubernetes | awk -F' ' '{print $2}' | awk -F',' '{print $1}')
  HTTP_CLUSTERIP_KUBEAPI_EP_IP=$(echo "${TMP_STR}" | awk -F: '{print $1}')
  HTTP_CLUSTERIP_KUBEAPI_EP_PORT=$(echo "${TMP_STR}" | awk -F: '{print $2}')

  # If Service Qualifier, update all services
  # This needs to be done after and searches using services.
  if [ ! -z "$FT_SVC_QUALIFIER" ] ; then
    HTTP_CLUSTERIP_POD_SVC_NAME=${HTTP_CLUSTERIP_POD_SVC_NAME}${FT_SVC_QUALIFIER}
    HTTP_CLUSTERIP_HOST_SVC_NAME=${HTTP_CLUSTERIP_HOST_SVC_NAME}${FT_SVC_QUALIFIER}
    HTTP_NODEPORT_SVC_NAME=${HTTP_NODEPORT_SVC_NAME}${FT_SVC_QUALIFIER}
    HTTP_NODEPORT_HOST_SVC_NAME=${HTTP_NODEPORT_HOST_SVC_NAME}${FT_SVC_QUALIFIER}
    IPERF_CLUSTERIP_POD_SVC_NAME=${IPERF_CLUSTERIP_POD_SVC_NAME}${FT_SVC_QUALIFIER}
    IPERF_CLUSTERIP_HOST_SVC_NAME=${IPERF_CLUSTERIP_HOST_SVC_NAME}${FT_SVC_QUALIFIER}
    IPERF_NODEPORT_SVC_NAME=${IPERF_NODEPORT_SVC_NAME}${FT_SVC_QUALIFIER}
    IPERF_NODEPORT_HOST_SVC_NAME=${IPERF_NODEPORT_HOST_SVC_NAME}${FT_SVC_QUALIFIER}
  fi
}
