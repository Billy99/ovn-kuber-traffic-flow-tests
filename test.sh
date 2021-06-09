#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


#
# Default values (possible to override)
#

# Test Control
TEST_CASE=${TEST_CASE:-0}
VERBOSE=${VERBOSE:-false}
FT_NOTES=${FT_NOTES:-true}
CURL=${CURL:-true}
CURL_CMD=${CURL_CMD:-curl -m 5}
IPERF=${IPERF:-false}
IPERF_CMD=${IPERF_CMD:-iperf3}
IPERF_TIME=${IPERF_TIME:-10}
OVN_TRACE=${OVN_TRACE:-false}
OVN_TRACE_CMD=${OVN_TRACE_CMD:-./ovnkube-trace -loglevel=5 -tcp}

# From YAML Files
CLIENT_POD_NAME_PREFIX=${CLIENT_POD_NAME_PREFIX:-ft-client-pod}
CLIENT_HOST_POD_NAME_PREFIX=${CLIENT_HOST_POD_NAME_PREFIX:-ft-client-pod-host}

HTTP_SERVER_POD_NAME=${HTTP_SERVER_POD_NAME:-ft-http-server-v4}
HTTP_SERVER_HOST_POD_NAME=${HTTP_SERVER_HOST_POD_NAME:-ft-http-server-host-v4}
HTTP_SERVER_POD_PORT=${HTTP_SERVER_POD_PORT:-8080}
HTTP_SERVER_HOST_POD_PORT=${HTTP_SERVER_HOST_POD_PORT:-8081}
HTTP_CLUSTERIP_SVC_NAME=${HTTP_CLUSTERIP_SVC_NAME:-ft-http-service-clusterip-v4}
HTTP_CLUSTERIP_HOST_SVC_NAME=${HTTP_CLUSTERIP_HOST_SVC_NAME:-ft-http-service-clusterip-host-v4}
HTTP_NODEPORT_SVC_NAME=${HTTP_NODEPORT_SVC_NAME:-ft-http-service-nodeport-v4}
HTTP_NODEPORT_HOST_SVC_NAME=${HTTP_NODEPORT_HOST_SVC_NAME:-ft-http-service-nodeport-host-v4}
HTTP_NODEPORT_POD_PORT=${HTTP_NODEPORT_POD_PORT:-30080}
HTTP_NODEPORT_HOST_PORT=${HTTP_NODEPORT_HOST_PORT:-30081}

IPERF_SERVER_POD_NAME=${IPERF_SERVER_POD_NAME:-ft-iperf-server-v4}
IPERF_SERVER_HOST_POD_NAME=${IPERF_SERVER_HOST_POD_NAME:-ft-iperf-server-host-v4}
IPERF_SERVER_POD_PORT=${IPERF_SERVER_POD_PORT:-5201}
IPERF_SERVER_HOST_POD_PORT=${IPERF_SERVER_HOST_POD_PORT:-5202}
IPERF_CLUSTERIP_SVC_NAME=${IPERF_CLUSTERIP_SVC_NAME:-ft-iperf-service-clusterip-v4}
IPERF_CLUSTERIP_HOST_SVC_NAME=${IPERF_CLUSTERIP_HOST_SVC_NAME:-ft-iperf-service-clusterip-host-v4}
IPERF_NODEPORT_SVC_NAME=${IPERF_NODEPORT_SVC_NAME:-ft-iperf-service-nodeport-v4}
IPERF_NODEPORT_HOST_SVC_NAME=${IPERF_NODEPORT_HOST_SVC_NAME:-ft-iperf-service-nodeport-host-v4}
IPERF_NODEPORT_POD_PORT=${IPERF_NODEPORT_POD_PORT:-30201}
IPERF_NODEPORT_HOST_PORT=${IPERF_NODEPORT_HOST_PORT:-30202}

POD_SERVER_STRING=${POD_SERVER_STRING:-"Server - Pod Backend Reached"}
HOST_SERVER_STRING=${HOST_SERVER_STRING:-"Server - Host Backend Reached"}
EXTERNAL_SERVER_STRING=${EXTERNAL_SERVER_STRING:-"The document has moved"}

# Cluster Node Names
FT_REQ_REMOTE_CLIENT_NODE=${FT_REQ_REMOTE_CLIENT_NODE:-all}

# External Access
EXTERNAL_IP=${EXTERNAL_IP:-8.8.8.8}
EXTERNAL_URL=${EXTERNAL_URL:-google.com}

# Trace Control
OVN_K_NAMESPACE=${OVN_K_NAMESPACE:-"ovn-kubernetes"}
SSL_ENABLE=${SSL_ENABLE:-"-noSSL"}
#
# Query for dynamic data
#
SERVER_NODE=`kubectl get pods -o wide | grep $HTTP_SERVER_POD_NAME  | awk -F' ' '{print $7}'`
HTTP_SERVER_IP=`kubectl get pods -o wide | grep $HTTP_SERVER_POD_NAME  | awk -F' ' '{print $6}'`
HTTP_SERVER_HOST_IP=`kubectl get pods -o wide | grep $HTTP_SERVER_HOST_POD_NAME  | awk -F' ' '{print $6}'`
IPERF_SERVER_IP=`kubectl get pods -o wide | grep $IPERF_SERVER_POD_NAME  | awk -F' ' '{print $6}'`
IPERF_SERVER_HOST_IP=`kubectl get pods -o wide | grep $IPERF_SERVER_HOST_POD_NAME  | awk -F' ' '{print $6}'`

LOCAL_CLIENT_NODE=$SERVER_NODE
REMOTE_CLIENT_NODE=$LOCAL_CLIENT_NODE


# Find the REMOTE NODE for POD and HOST POD. (REMOTE is a node server is NOT running on)
NODE_ARRAY=($(kubectl get nodes --no-headers=true | awk -F' ' '{print $1}'))
for i in "${!NODE_ARRAY[@]}"
do
  # Check for non-master (KIND clusters don't have "worker" role set)
  kubectl get node ${NODE_ARRAY[$i]} --no-headers=true | awk -F' ' '{print $3}' | grep -q master
  if [ "$?" == 1 ]; then
    if [ "$FT_REQ_REMOTE_CLIENT_NODE" == all ] || [ "$FT_REQ_REMOTE_CLIENT_NODE" == "${NODE_ARRAY[$i]}" ]; then
      if [ "$LOCAL_CLIENT_NODE" != "${NODE_ARRAY[$i]}" ]; then
        REMOTE_CLIENT_NODE=${NODE_ARRAY[$i]}
      fi
    fi
  fi
done
if [ "$REMOTE_CLIENT_NODE" == "$LOCAL_CLIENT_NODE" ]; then
  if [ "$FT_REQ_REMOTE_CLIENT_NODE" == "$REMOTE_CLIENT_NODE" ]; then
    echo -e "${BLUE}ERROR: As requested, REMOTE_CLIENT_NODE is same as LOCAL_CLIENT_NODE: $LOCAL_CLIENT_NODE${NC}\r\n"
  else
    echo -e "${RED}ERROR: Unable to find REMOTE_CLIENT_NODE. Using LOCAL_CLIENT_NODE: $LOCAL_CLIENT_NODE${NC}\r\n"
  fi
fi


# POD Values
#

LOCAL_CLIENT_POD=`kubectl get pods --selector=name=${CLIENT_POD_NAME_PREFIX} -o wide | grep -w "$LOCAL_CLIENT_NODE" | awk -F' ' '{print $1}'`
REMOTE_CLIENT_POD=`kubectl get pods --selector=name=${CLIENT_POD_NAME_PREFIX} -o wide| grep -w "$REMOTE_CLIENT_NODE" | awk -F' ' '{print $1}'`

HTTP_CLUSTERIP_SERVICE_IPV4=`kubectl get services | grep $HTTP_CLUSTERIP_SVC_NAME | awk -F' ' '{print $3}'`
HTTP_CLUSTERIP_HOST_SERVICE_IPV4=`kubectl get services | grep $HTTP_CLUSTERIP_HOST_SVC_NAME | awk -F' ' '{print $3}'`
HTTP_NODEPORT_SERVICE_IPV4=`kubectl get services | grep $HTTP_NODEPORT_SVC_NAME | awk -F' ' '{print $3}'`
HTTP_NODEPORT_HOST_SVC_IPV4=`kubectl get services | grep $HTTP_NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $3}'`

IPERF_CLUSTERIP_SERVICE_IPV4=`kubectl get services | grep $IPERF_CLUSTERIP_SVC_NAME | awk -F' ' '{print $3}'`
IPERF_CLUSTERIP_HOST_SERVICE_IPV4=`kubectl get services | grep $IPERF_CLUSTERIP_HOST_SVC_NAME | awk -F' ' '{print $3}'`
IPERF_NODEPORT_SERVICE_IPV4=`kubectl get services | grep $IPERF_NODEPORT_SVC_NAME | awk -F' ' '{print $3}'`
IPERF_NODEPORT_HOST_SVC_IPV4=`kubectl get services | grep $IPERF_NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $3}'`

# HOST POD Values

LOCAL_CLIENT_HOST_POD=`kubectl get pods --selector=name=${CLIENT_HOST_POD_NAME_PREFIX} -o wide | grep -w "$LOCAL_CLIENT_NODE" | awk -F' ' '{print $1}'`
REMOTE_CLIENT_HOST_POD=`kubectl get pods --selector=name=${CLIENT_HOST_POD_NAME_PREFIX} -o wide | grep -w "$REMOTE_CLIENT_NODE" | awk -F' ' '{print $1}'`



# NOTE: env in the container has values that could be used instead of using the above commands:
#
# kubectl exec -it $LOCAL_CLIENT_POD -- env
#  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#  HOSTNAME=ft-client-w2rps
#  container=docker
#  MY_WEB_SERVICE_NODE_V4_SERVICE_PORT=80
#  MY_WEB_SERVICE_NODE_V4_PORT_80_TCP_PORT=80
#  KUBERNETES_PORT_443_TCP_PROTO=tcp
#  MY_WEB_SERVICE_NODE_V4_SERVICE_HOST=10.96.66.203
#  MY_WEB_SERVICE_NODE_V4_PORT=tcp://10.96.66.203:80
#  MY_WEB_SERVICE_NODE_V4_PORT_80_TCP=tcp://10.96.66.203:80
#  KUBERNETES_SERVICE_HOST=10.96.0.1
#  MY_WEB_SERVICE_NODE_V4_PORT_80_TCP_PROTO=tcp
#  KUBERNETES_SERVICE_PORT_HTTPS=443
#  KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
#  KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
#  MY_WEB_SERVICE_NODE_V4_SERVICE_PORT_WEBSERVER_NODE_V4_80=80
#  MY_WEB_SERVICE_NODE_V4_PORT_80_TCP_ADDR=10.96.66.203
#  KUBERNETES_SERVICE_PORT=443
#  KUBERNETES_PORT=tcp://10.96.0.1:443
#  KUBERNETES_PORT_443_TCP_PORT=443
#
# kubectl exec -it $LOCAL_CLIENT_POD -- /bin/sh -c 'curl "http://$MY_WEB_SERVICE_NODE_V4_SERVICE_HOST:$MY_WEB_SERVICE_NODE_V4_SERVICE_PORT/"'


#
# Functions
#

dump-working-data() {
  echo
  echo "Default/Override Values:"
  echo "  Test Control:"
  echo "    TEST_CASE (0 means all)            $TEST_CASE"
  echo "    VERBOSE                            $VERBOSE"
  echo "    FT_NOTES                           $FT_NOTES"
  echo "    CURL                               $CURL"
  echo "    CURL_CMD                           $CURL_CMD"
  echo "    IPERF                              $IPERF"
  echo "    IPERF_CMD                          $IPERF_CMD"
  echo "    IPERF_TIME                         $IPERF_TIME"
  echo "    OVN_TRACE                          $OVN_TRACE"
  echo "    OVN_TRACE_CMD                      $OVN_TRACE_CMD"
  echo "    FT_REQ_REMOTE_CLIENT_NODE          $FT_REQ_REMOTE_CLIENT_NODE"
  echo "  OVN Trace Control:"
  echo "    OVN_K_NAMESPACE                    $OVN_K_NAMESPACE"
  echo "    SSL_ENABLE                         $SSL_ENABLE"
  echo "  From YAML Files:"
  echo "    CLIENT_POD_NAME_PREFIX             $CLIENT_POD_NAME_PREFIX"
  echo "    http Server:"
  echo "      HTTP_SERVER_POD_NAME             $HTTP_SERVER_POD_NAME"
  echo "      HTTP_SERVER_HOST_POD_NAME        $HTTP_SERVER_HOST_POD_NAME"
  echo "      HTTP_SERVER_POD_PORT             $HTTP_SERVER_POD_PORT"
  echo "      HTTP_SERVER_HOST_POD_PORT        $HTTP_SERVER_HOST_POD_PORT"
  echo "      HTTP_CLUSTERIP_SVC_NAME          $HTTP_CLUSTERIP_SVC_NAME"
  echo "      HTTP_CLUSTERIP_HOST_SVC_NAME     $HTTP_CLUSTERIP_HOST_SVC_NAME"
  echo "      HTTP_NODEPORT_SVC_NAME           $HTTP_NODEPORT_SVC_NAME"
  echo "      HTTP_NODEPORT_HOST_SVC_NAME      $HTTP_NODEPORT_HOST_SVC_NAME"
  echo "      HTTP_NODEPORT_POD_PORT           $HTTP_NODEPORT_POD_PORT"
  echo "      HTTP_NODEPORT_HOST_PORT          $HTTP_NODEPORT_HOST_PORT"
  echo "    iperf Server:"
  echo "      IPERF_SERVER_POD_NAME            $IPERF_SERVER_POD_NAME"
  echo "      IPERF_SERVER_HOST_POD_NAME       $IPERF_SERVER_HOST_POD_NAME"
  echo "      IPERF_SERVER_POD_PORT            $IPERF_SERVER_POD_PORT"
  echo "      IPERF_SERVER_HOST_POD_PORT       $IPERF_SERVER_HOST_POD_PORT"
  echo "      IPERF_CLUSTERIP_SVC_NAME         $IPERF_CLUSTERIP_SVC_NAME"
  echo "      IPERF_CLUSTERIP_HOST_SVC_NAME    $IPERF_CLUSTERIP_HOST_SVC_NAME"
  echo "      IPERF_NODEPORT_SVC_NAME          $IPERF_NODEPORT_SVC_NAME"
  echo "      IPERF_NODEPORT_HOST_SVC_NAME     $IPERF_NODEPORT_HOST_SVC_NAME"
  echo "      IPERF_NODEPORT_POD_PORT          $IPERF_NODEPORT_POD_PORT"
  echo "      IPERF_NODEPORT_HOST_PORT         $IPERF_NODEPORT_HOST_PORT"
  echo "    POD_SERVER_STRING                  $POD_SERVER_STRING"
  echo "    HOST_SERVER_STRING                 $HOST_SERVER_STRING"
  echo "    EXTERNAL_SERVER_STRING             $EXTERNAL_SERVER_STRING"
  echo "  External Access:"
  echo "    EXTERNAL_IP                        $EXTERNAL_IP"
  echo "    EXTERNAL_URL                       $EXTERNAL_URL"
  echo "Queried Values:"
  echo "  Pod Backed:"
  echo "    HTTP_SERVER_IP                     $HTTP_SERVER_IP"
  echo "    IPERF_SERVER_IP                    $IPERF_SERVER_IP"
  echo "    SERVER_NODE                        $SERVER_NODE"
  echo "    LOCAL_CLIENT_NODE                  $LOCAL_CLIENT_NODE"
  echo "    LOCAL_CLIENT_POD                   $LOCAL_CLIENT_POD"
  echo "    REMOTE_CLIENT_NODE                 $REMOTE_CLIENT_NODE"
  echo "    REMOTE_CLIENT_POD                  $REMOTE_CLIENT_POD"
  echo "    HTTP_CLUSTERIP_SERVICE_IPV4        $HTTP_CLUSTERIP_SERVICE_IPV4"
  echo "    HTTP_NODEPORT_SERVICE_IPV4         $HTTP_NODEPORT_SERVICE_IPV4"
  echo "    IPERF_CLUSTERIP_SERVICE_IPV4       $IPERF_CLUSTERIP_SERVICE_IPV4"
  echo "    IPERF_NODEPORT_SERVICE_IPV4        $IPERF_NODEPORT_SERVICE_IPV4"
  echo "  Host backed:"
  echo "    HTTP_SERVER_HOST_IP                $HTTP_SERVER_HOST_IP"
  echo "    IPERF_SERVER_HOST_IP               $IPERF_SERVER_HOST_IP"
  echo "    SERVER_HOST_NODE                   $SERVER_NODE"
  echo "    LOCAL_CLIENT_HOST_NODE             $LOCAL_CLIENT_NODE"
  echo "    LOCAL_CLIENT_HOST_POD              $LOCAL_CLIENT_HOST_POD"
  echo "    REMOTE_CLIENT_HOST_NODE            $REMOTE_CLIENT_NODE"
  echo "    REMOTE_CLIENT_HOST_POD             $REMOTE_CLIENT_HOST_POD"
  echo "    HTTP_CLUSTERIP_HOST_SERVICE_IPV4   $HTTP_CLUSTERIP_HOST_SERVICE_IPV4"
  echo "    HTTP_NODEPORT_HOST_SVC_IPV4        $HTTP_NODEPORT_HOST_SVC_IPV4"
  echo "    IPERF_CLUSTERIP_HOST_SERVICE_IPV4  $IPERF_CLUSTERIP_HOST_SERVICE_IPV4"
  echo "    IPERF_NODEPORT_HOST_SVC_IPV4       $IPERF_NODEPORT_HOST_SVC_IPV4"
  echo
}


process-curl() {
  # The following VARIABLES are used by this function in the following combinations:
  #   From outside Cluster:
  #     TEST_SERVER_HTTP_DST
  #     TEST_SERVER_HTTP_DST_PORT
  #   No Port:
  #     TEST_CLIENT_POD
  #     TEST_SERVER_HTTP_DST
  #   Use Destination and Port:
  #     TEST_CLIENT_POD
  #     TEST_SERVER_HTTP_DST
  #     TEST_SERVER_HTTP_DST_PORT
  # If not used, VARIABLE should be blank for 'if [ -z "${VARIABLE}" ]' test.

  if [ -z "${TEST_CLIENT_POD}" ]; then
    # From External (no 'kubectl exec') 
    echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
    TMP_OUTPUT=`$CURL_CMD "http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/"`
  elif [ -z "${TEST_SERVER_HTTP_DST_PORT}" ]; then
    # No Port, so leave off Port from command
    echo "kubectl exec -it ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}/\""
    TMP_OUTPUT=`kubectl exec -it ${TEST_CLIENT_POD} -- $CURL_CMD "http://${TEST_SERVER_HTTP_DST}/"`
  else
    # Default command
    echo "kubectl exec -it ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
    TMP_OUTPUT=`kubectl exec -it ${TEST_CLIENT_POD} -- $CURL_CMD "http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/"`
  fi

  # Dump command output
  if [ "$VERBOSE" == true ]; then
    echo "${TMP_OUTPUT}"
  fi

  # Print SUCCESS or FAILURE
  echo "${TMP_OUTPUT}" | grep -cq "${TEST_SERVER_RSP}" && echo -e "${GREEN}SUCCESS${NC}\r\n" || echo -e "${RED}FAILED${NC}\r\n"
}

process-iperf() {
  # The following VARIABLES are used by this function:
  #     TEST_CLIENT_POD
  #     TEST_FILENAME
  #     TEST_SERVER_IPERF_DST
  #     TEST_SERVER_IPERF_DST_PORT

  echo "kubectl exec -it $TEST_CLIENT_POD -- $IPERF_CMD -c $TEST_SERVER_IPERF_DST -p $TEST_SERVER_IPERF_DST_PORT -t $IPERF_TIME"
  kubectl exec -it $TEST_CLIENT_POD -- $IPERF_CMD -c $TEST_SERVER_IPERF_DST -p $TEST_SERVER_IPERF_DST_PORT -t $IPERF_TIME  > iperf-logs/$TEST_FILENAME

  # Dump command output
  if [ "$VERBOSE" == true ]; then
    echo "Full Output (from iperf-logs/${TEST_FILENAME}):"
    cat iperf-logs/$TEST_FILENAME
  else
    echo "Summary (see iperf-logs/${TEST_FILENAME} for full detail):"
    cat iperf-logs/$TEST_FILENAME | grep -B 1 -A 1 "sender"
  fi

  # Print SUCCESS or FAILURE
  cat iperf-logs/$TEST_FILENAME | grep -cq "sender" && echo -e "${GREEN}SUCCESS${NC}\r\n" || echo -e "${RED}FAILED${NC}\r\n"
}

process-ovn-trace() {
  # The following VARIABLES are used by this function in the following combinations:
  #   Use Destination and Port:
  #     TEST_CLIENT_POD
  #     TEST_FILENAME
  #     TEST_SERVER_OVNTRACE_DST
  #     TEST_SERVER_OVNTRACE_DST_PORT
  #   Use Remote Host:
  #     TEST_CLIENT_POD
  #     TEST_FILENAME
  #     TEST_SERVER_OVNTRACE_RMTHOST
  #   Use Service and Port:
  #     TEST_CLIENT_POD
  #     TEST_FILENAME
  #     TEST_SERVER_OVNTRACE_SERVICE
  #     TEST_SERVER_OVNTRACE_DST_PORT
  # If not used, VARIABLE should be blank for 'if [ -z "${VARIABLE}" ]' test.

  echo "OVN-TRACE: BEGIN"
  TRACE_FILENAME="ovn-traces/${TEST_FILENAME}"

  if [ ! -z "${TEST_SERVER_OVNTRACE_DST}" ]; then
    echo "${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \\"
    echo "  -src=$TEST_CLIENT_POD -dst=$TEST_SERVER_OVNTRACE_DST -dst-port=$TEST_SERVER_OVNTRACE_DST_PORT \\"
    echo "  -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME"

    ${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \
      -src=$TEST_CLIENT_POD -dst=$TEST_SERVER_OVNTRACE_DST -dst-port=$TEST_SERVER_OVNTRACE_DST_PORT \
      -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME
  elif [ ! -z "${TEST_SERVER_OVNTRACE_RMTHOST}" ]; then
    echo ".${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \\"
    echo "  -src=$TEST_CLIENT_POD -remotehost=$TEST_SERVER_OVNTRACE_RMTHOST \\"
    echo "  -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME"

    ${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \
      -src=$TEST_CLIENT_POD -remotehost=$TEST_SERVER_OVNTRACE_RMTHOST \
      -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME
  else
    echo "${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \\"
    echo "  -src=$TEST_CLIENT_POD -service=$TEST_SERVER_OVNTRACE_SERVICE -dst-port=$TEST_SERVER_OVNTRACE_DST_PORT \\"
    echo "  -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME"

    ${OVN_TRACE_CMD} -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE \
      -src=$TEST_CLIENT_POD -service=$TEST_SERVER_OVNTRACE_SERVICE -dst-port=$TEST_SERVER_OVNTRACE_DST_PORT \
      -kubeconfig=$KUBECONFIG 2> $TRACE_FILENAME
  fi

  echo "OVN-TRACE: END (see $TRACE_FILENAME for full detail)"
  echo
}

#
# Main Body
#

# Test for '--help'
if [ ! -z "$1" ] ; then
  if [ "$1" == help ] || [ "$1" == "--help" ] ; then
    echo
    echo "This script uses ENV Variables to control test:"
    echo "  TEST_CASE (0 means all)    - Run a single test. Example:"
    echo "                                 TEST_CASE=3 ./test.sh"
    echo "  VERBOSE                    - Command output is masked by default. Enable curl output."
    echo "                               Example:"
    echo "                                 VERBOSE=true ./test.sh"
    echo "  OVN_TRACE                  - 'ovn-trace' is run on each flow by default. Disable 'ovn-trace'"
    echo "                               Example:"
    echo "                                 OVN_TRACE=false ./test.sh"
    echo "  FT_NOTES                   - Print notes (in blue) where tests are failing but maybe shouldn't be."
    echo "                               On by default. Example:"
    echo "                                 FT_NOTES=false ./test.sh"
    echo "  CURL_CMD                   - Curl command to run. Allows additional parameters to be"
    echo "                               inserted. Example:"
    echo "                                 CURL_CMD=\"curl -v --connect-timeout 5\" ./test.sh"
    echo "  FT_REQ_REMOTE_CLIENT_NODE  - Node to use when sending from client pod on different node"
    echo "                               from server. Example:"
    echo "                                 FT_REQ_REMOTE_CLIENT_NODE=ovn-worker4 ./test.sh"
    echo "  FT_REQ_SERVER_NODE         - Node to run server pods on. Must be set before launching"
    echo "                               pods. Example:"
    echo "                                 FT_REQ_SERVER_NODE=ovn-worker3 ./launch.sh"

    dump-working-data
  else
    echo
    echo "Unknown input, try using \"./test.sh --help\""
    echo
  fi

  exit 0
fi

dump-working-data

#
# Test each scenario
#
if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 1 ]; then
  echo
  echo "FLOW 01: Typical Pod to Pod traffic (using cluster subnet)"
  echo "----------------------------------------------------------"

  echo
  echo "*** 1-a: Pod to Pod (Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_POD
  TEST_FILENAME="1a-pod2pod-same-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_SERVER_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_RSP=$POD_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_SERVER_POD_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=$HTTP_SERVER_POD_NAME
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 1-b: Pod to Pod (Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="1b-pod2pod-diff-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_SERVER_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_RSP=$POD_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_SERVER_POD_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=$HTTP_SERVER_POD_NAME
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 2 ]; then
  echo
  echo "FLOW 02: Pod -> Cluster IP Service traffic"
  echo "------------------------------------------"

  echo
  echo "*** 2-a: Pod -> Cluster IP Service traffic (Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_POD
  TEST_FILENAME="2a-pod2clusterIPsvc-same-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_RSP=$POD_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_SERVICE_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_SERVER_POD_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 2-b: Pod -> Cluster IP Service traffic (Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="2b-pod2clusterIPsvc-diff-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_RSP=$POD_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_SERVICE_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_SERVER_POD_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 3 ]; then
  echo
  echo "FLOW 03: Pod -> NodePort Service traffic (pod/host backend)"
  echo "-----------------------------------------------------------"

  echo
  echo "*** 3-a: Pod -> NodePort Service traffic (pod backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_POD
  TEST_FILENAME="3a-pod2nodePortsvc-pod-backend-same-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_PORT
    echo "curl HostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_POD_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 3-b: Pod -> NodePort Service traffic (pod backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="3b-pod2nodePortsvc-pod-backend-diff-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_PORT
    echo "curl HostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_POD_PORT
    #process-iperf
    echo "kubectl exec -it $TEST_CLIENT_POD -- $IPERF_CMD -c $TEST_SERVER_IPERF_DST -p $TEST_SERVER_IPERF_DST_PORT -t $IPERF_TIME"
    echo -e "${RED}iperf Skipped - HostIP:NODEPORT Different Node${NC}"
    echo
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 3-c: Pod -> NodePort Service traffic (host networked pod backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_POD
  TEST_FILENAME="3c-pod2nodePortsvc-host-backend-same-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_PORT
    echo "curl HostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_HOST_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 3-d: Pod -> NodePort Service traffic (host networked pod backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="3d-pod2nodePortsvc-host-backend-diff-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    echo "curl SvcClusterIP:SvcPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_PORT
    echo "curl HostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    echo "curl SvcName:SvcPORT"
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_HOST_PORT
    #process-iperf
    echo "kubectl exec -it $TEST_CLIENT_POD -- $IPERF_CMD -c $TEST_SERVER_IPERF_DST -p $TEST_SERVER_IPERF_DST_PORT -t $IPERF_TIME"
    echo -e "${RED}iperf Skipped - HostIP:NODEPORT Different Node${NC}"
    echo
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi

if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 4 ]; then
  echo
  echo "FLOW 04: Pod/Host Pod -> External Network (egress traffic)"
  echo "----------------------------------------------------------"

  echo
  echo "*** 4-a: Pod -> External Network (egress traffic) ***"
  echo
  
  TEST_CLIENT_POD=$REMOTE_CLIENT_POD
  TEST_FILENAME="4a-pod2externalHost.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$EXTERNAL_URL
    TEST_SERVER_HTTP_DST_PORT=
    TEST_SERVER_RSP=$EXTERNAL_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}iperf Skipped - No external iperf server.${NC}"
      echo
    fi
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=
    TEST_SERVER_OVNTRACE_RMTHOST=$EXTERNAL_SERVER_STRING
    process-ovn-trace
  fi


  echo
  echo "*** 4-b: Host Pod -> External Network (egress traffic) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="4b-hostpod2externalHost.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$EXTERNAL_URL
    TEST_SERVER_HTTP_DST_PORT=
    TEST_SERVER_RSP=$EXTERNAL_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}iperf Skipped - No external iperf server.${NC}"
      echo
    fi
  fi

  if [ "$OVN_TRACE" == true ]; then 
    if [ "$FT_NOTES" == true ]; then
      echo "OVN-TRACE: BEGIN"
      echo -e "${BLUE}ovn-trace Skipped - Traffic is never in OVN, just exiting eth0 on host.${NC}"
      echo "OVN-TRACE: END"
      echo
    fi
  fi
fi

if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 5 ]; then
  echo
  echo "FLOW 05: Host Pod -> Cluster IP Service traffic (pod backend)"
  echo "---------------------------------------------------------"

  echo
  echo "*** 5-a: Host Pod -> Cluster IP Service traffic (pod backend - Same Node) ***"
  echo
  
  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="5a-hostpod2clusterIPsvc-pod-backend-same-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_RSP=$POD_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_SERVICE_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_SERVER_POD_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 5-b: Host Pod -> Cluster IP Service traffic (pod backend - Different Node) ***"
  echo
  
  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="5b-hostpod2clusterIPsvc-pod-backend-diff-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_RSP=$POD_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_SERVICE_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_SERVER_POD_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 6 ]; then
  echo
  echo "FLOW 06: Host Pod -> NodePort Service traffic (pod backend)"
  echo "-------------------------------------------------------"

  echo
  echo "*** 6-a: Host Pod -> NodePort Service traffic (pod backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="6a-hostpod2nodePortsvc-pod-backend-same-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    echo "curl SvcClusterIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_PORT
    echo "curl hostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    echo "curl SvcName:NODEPORT"
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}curl: (6) Could not resolve host: ft-http-service-node-v4; Unknown error${NC}"
      echo -e "${BLUE}Should this work? -- GOOD QUESTION${NC}"
    fi
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_POD_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
fi


  echo
  echo "*** 6-b: Host Pod -> NodePort Service traffic (pod backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="6b-hostpod2nodePortsvc-pod-backend-diff-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    echo "curl SvcClusterIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_PORT
    echo "curl hostIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    #echo "curl SvcName:NODEPORT"
    #process-curl
    if [ "$FT_NOTES" == true ]; then
      echo "curl SvcName:NODEPORT"
      echo "kubectl exec -it ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
      echo -e "${BLUE}curl: (6) Could not resolve host: ft-http-service-node-v4; Unknown error${NC}"
      echo -e "${BLUE}Should this work?${NC}"
      echo
    fi
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_POD_PORT
    #process-iperf
    echo "kubectl exec -it $TEST_CLIENT_POD -- $IPERF_CMD -c $TEST_SERVER_IPERF_DST -p $TEST_SERVER_IPERF_DST_PORT -t $IPERF_TIME"
    echo -e "${RED}iperf Skipped - HostIP:NODEPORT Different Node${NC}"
    echo
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 7 ]; then
  echo
  echo "FLOW 07: Host Pod -> Cluster IP Service traffic (host networked pod backend)"
  echo "------------------------------------------------------------------------"

  echo
  echo "*** 7-a: Host Pod -> Cluster IP Service traffic (host networked pod backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="7a-hostpod2clusterIPsvc-host-backend-same-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    TEST_SERVER_RSP=$HOST_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_HOST_SERVICE_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_SERVER_HOST_POD_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi


  echo
  echo "*** 7-b: Host Pod -> Cluster IP Service traffic (host networked pod backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="7b-hostpod2clusterIPsvc-host-backend-diff-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_HTTP_DST=$HTTP_CLUSTERIP_HOST_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    TEST_SERVER_RSP=$HOST_SERVER_STRING
    process-curl
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_CLUSTERIP_HOST_SERVICE_IPV4
    TEST_SERVER_IPERF_DST_PORT=$IPERF_SERVER_HOST_POD_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_CLUSTERIP_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=
    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 8 ]; then
  echo
  echo "FLOW 08: Host Pod -> NodePort Service traffic (host networked pod backend)"
  echo "----------------------------------------------------------------------"

  echo
  echo "*** 8-a: Host Pod -> NodePort Service traffic (host networked pod backend - Same Node) ***"
  echo

  TEST_CLIENT_POD=$LOCAL_CLIENT_HOST_POD
  TEST_FILENAME="8a-hostpod2nodePortsvc-host-backend-same-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    echo "curl SvcClusterIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_PORT
    echo "curl EndPointIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    #echo "curl SvcName:NODEPORT"
    #process-curl
    if [ "$FT_NOTES" == true ]; then
      echo "curl SvcName:NODEPORT"
      echo "kubectl exec -it ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
      echo -e "${BLUE}Test Skipped - the host has no idea about svc DNS resolution${NC}"
      echo
    fi
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_HOST_PORT
    process-iperf
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=

    echo "ovnkube-trace SvcName:NODEPORT"
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}If Test Skipped - why trace the same?${NC}"
    fi

    process-ovn-trace
  fi


  echo
  echo "*** 8-b: Host Pod -> NodePort Service traffic (host networked pod backend - Different Node) ***"
  echo

  TEST_CLIENT_POD=$REMOTE_CLIENT_HOST_POD
  TEST_FILENAME="8b-hostpod2nodePortsvc-host-backend-diff-node.txt"

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    echo "curl SvcClusterIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_PORT
    echo "curl EndPointIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    #echo "curl SvcName:NODEPORT"
    #process-curl
    if [ "$FT_NOTES" == true ]; then
      echo "curl SvcName:NODEPORT"
      echo "kubectl exec -it ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
      echo -e "${BLUE}Test Skipped - the host has no idea about svc DNS resolution${NC}"
      echo
    fi
  fi

  if [ "$IPERF" == true ]; then
    TEST_SERVER_IPERF_DST=$IPERF_SERVER_HOST_IP
    TEST_SERVER_IPERF_DST_PORT=$IPERF_NODEPORT_HOST_PORT
    #process-iperf
    echo "kubectl exec -it $TEST_CLIENT_POD -- $IPERF_CMD -c $TEST_SERVER_IPERF_DST -p $TEST_SERVER_IPERF_DST_PORT -t $IPERF_TIME"
    echo -e "${RED}iperf Skipped - HostIP:NODEPORT Different Node${NC}"
    echo
  fi

  if [ "$OVN_TRACE" == true ]; then 
    TEST_SERVER_OVNTRACE_SERVICE=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_OVNTRACE_DST=
    TEST_SERVER_OVNTRACE_DST_PORT=$HTTP_SERVER_HOST_POD_PORT
    TEST_SERVER_OVNTRACE_RMTHOST=

    echo "ovnkube-trace SvcName:NODEPORT"
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}If Test Skipped - why trace the same?${NC}"
    fi

    process-ovn-trace
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 9 ]; then
  echo
  echo "FLOW 09: External Network Traffic -> NodePort/External IP Service (ingress traffic)"
  echo "-----------------------------------------------------------------------------------"

  echo
  echo "*** 9-a: External Network Traffic -> NodePort/External IP Service (ingress traffic - pod backend) ***"
  echo

  TEST_CLIENT_POD=

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$POD_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_SERVER_POD_PORT
    #echo "curl SvcClusterIP:NODEPORT"
    #process-curl
    if [ "$FT_NOTES" == true ]; then
      echo "curl SvcClusterIP:NODEPORT"
      echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
      echo -e "${BLUE}Test Skipped - SVCIP is only in cluster network${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_PORT
    echo "curl EndPointIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_POD_PORT
    #echo "curl SvcName:NODEPORT"
    #process-curl
    if [ "$FT_NOTES" == true ]; then
      echo "curl SvcName:NODEPORT"
      echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
      echo -e "${BLUE}Test Skipped - SVC HostName only resolves in cluster network${NC}"
      echo
    fi
  fi


  if [ "$IPERF" == true ]; then
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}iperf Skipped - No external iperf client.${NC}"
      echo
    fi
  fi

  if [ "$OVN_TRACE" == true ]; then 
    if [ "$FT_NOTES" == true ]; then
      echo "OVN-TRACE: BEGIN"
      echo -e "${BLUE}ovn-trace Skipped.${NC}"
      echo "OVN-TRACE: END"
      echo
    fi
  fi


  echo
  echo "*** 9-b: External Network Traffic -> NodePort/External IP Service (ingress traffic - host backend) ***"
  echo

  TEST_CLIENT_POD=

  if [ "$CURL" == true ]; then
    TEST_SERVER_RSP=$HOST_SERVER_STRING

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_SERVICE_IPV4
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_PORT
    #echo "curl SvcClusterIP:NODEPORT"
    #process-curl
    if [ "$FT_NOTES" == true ]; then
      echo "curl SvcClusterIP:NODEPORT"
      echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
      echo -e "${BLUE}Test Skipped - SVCIP is only in cluster network${NC}"
      echo
    fi

    TEST_SERVER_HTTP_DST=$HTTP_SERVER_HOST_IP
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_PORT
    echo "curl EndPointIP:NODEPORT"
    process-curl

    TEST_SERVER_HTTP_DST=$HTTP_NODEPORT_HOST_SVC_NAME
    TEST_SERVER_HTTP_DST_PORT=$HTTP_NODEPORT_HOST_PORT
    #echo "curl SvcName:NODEPORT"
    #process-curl
    if [ "$FT_NOTES" == true ]; then
      echo "curl SvcName:NODEPORT"
      echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/\""
      echo -e "${BLUE}Test Skipped - SVC HostName only resolves in cluster network${NC}"
      echo
    fi
  fi

  if [ "$IPERF" == true ]; then
    if [ "$FT_NOTES" == true ]; then
      echo -e "${BLUE}iperf Skipped - No external iperf client.${NC}"
      echo
    fi
  fi

  if [ "$OVN_TRACE" == true ]; then 
    if [ "$FT_NOTES" == true ]; then
      echo "OVN-TRACE: BEGIN"
      echo -e "${BLUE}ovn-trace Skipped.${NC}"
      echo "OVN-TRACE: END"
      echo
    fi
  fi
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 10 ]; then
  echo
  echo "FLOW 10: External network traffic -> pods (multiple external gw traffic)"
  echo "------------------------------------------------------------------------"

  if [ "$FT_NOTES" == true ]; then
    echo
    echo -e "${BLUE}NOT IMPLEMENTED${NC}"
    echo
  fi
fi

