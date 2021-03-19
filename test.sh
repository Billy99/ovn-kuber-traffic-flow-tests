#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


#
# Default values (possible to override)
#

# Test Control
DEBUG_TEST=${DEBUG_TEST:-false}
TEST_CASE=${TEST_CASE:-0}
VERBOSE=${VERBOSE:-false}
CURL_CMD=${CURL_CMD:-curl -m 5}

# From YAML Files
SERVER_POD_NAME=${SERVER_POD_NAME:-web-server-v4}
SERVER_CLUSTERIP_POD_NAME=${SERVER_CLUSTERIP_POD_NAME:-web-server-clusterip-v4}
SERVER_NODEPORT_POD_NAME=${SERVER_NODEPORT_POD_NAME:-web-server-nodeport-v4}
SERVER_HOST_POD_NAME=${SERVER_HOST_POD_NAME:-web-server-host-node-v4}
SERVER_POD_PORT=${SERVER_POD_PORT:-8080}
SERVER_HOST_POD_PORT=${SERVER_HOST_POD_PORT:-8081}
CLIENT_POD_NAME_PREFIX=${CLIENT_POD_NAME_PREFIX:-web-client-pod}
CLIENT_HOST_POD_NAME_PREFIX=${CLIENT_HOST_POD_NAME_PREFIX:-web-client-host}
CLUSTERIP_SVC_NAME=${CLUSTERIP_SVC_NAME:-web-service-clusterip-v4}
NODEPORT_SVC_NAME=${NODEPORT_SVC_NAME:-web-service-nodeport-v4}
NODEPORT_HOST_SVC_NAME=${NODEPORT_HOST_SVC_NAME:-web-service-host-node-v4}
NODEPORT_POD_PORT=${NODEPORT_POD_PORT:-30080}
NODEPORT_HOST_PORT=${NODEPORT_HOST_PORT:-30081}
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
SERVER_NODE=`kubectl get pods -o wide | grep $SERVER_POD_NAME  | awk -F' ' '{print $7}'`
SERVER_IP=`kubectl get pods -o wide | grep $SERVER_POD_NAME  | awk -F' ' '{print $6}'`
SERVER_HOST_IP=`kubectl get pods -o wide | grep $SERVER_HOST_POD_NAME  | awk -F' ' '{print $6}'`

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

LOCAL_CLIENT_POD=`kubectl get pods -o wide | grep $CLIENT_POD_NAME_PREFIX | grep -w "$LOCAL_CLIENT_NODE" | awk -F' ' '{print $1}'`
REMOTE_CLIENT_POD=`kubectl get pods -o wide | grep $CLIENT_POD_NAME_PREFIX | grep -w "$REMOTE_CLIENT_NODE" | awk -F' ' '{print $1}'`

CLUSTERIP_SERVICE_IPV4=`kubectl get services | grep $CLUSTERIP_SVC_NAME | awk -F' ' '{print $3}'`
NODEPORT_SERVICE_IPV4=`kubectl get services | grep $NODEPORT_SVC_NAME | awk -F' ' '{print $3}'`
NODEPORT_HOST_SVC_IPV4=`kubectl get services | grep $NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $3}'`
#NODEPORT_ENDPOINT_IPV4=`kubectl get endpoints | grep $NODEPORT_SVC_NAME | awk -F' ' '{print $2}'`
NODEPORT_ENDPOINT_IPV4=$SERVER_IP

# HOST POD Values
#

LOCAL_CLIENT_HOST_POD=`kubectl get pods -o wide | grep $CLIENT_HOST_POD_NAME_PREFIX | grep -w "$LOCAL_CLIENT_NODE" | awk -F' ' '{print $1}'`
REMOTE_CLIENT_HOST_POD=`kubectl get pods -o wide | grep $CLIENT_HOST_POD_NAME_PREFIX | grep -w "$REMOTE_CLIENT_NODE" | awk -F' ' '{print $1}'`

NODEPORT_HOST_CLUSTER_IPV4=`kubectl get services | grep $NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $3}'`
#NODEPORT_HOST_ENDPOINT_IPV4=`kubectl get endpoints | grep $NODEPORT_HOST_SVC_NAME | awk -F' ' '{print $2}'`
NODEPORT_HOST_ENDPOINT_IPV4=$SERVER_HOST_IP


# NOTE: env in the container has values that could be used instead of using the above commands:
#
# kubectl exec -it $LOCAL_CLIENT_POD -- env
#  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#  HOSTNAME=web-client-w2rps
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
# Dump working data
#
dump-working-data() {
  echo
  echo "Default/Override Values:"
  echo "  Test Control:"
  echo "    DEBUG_TEST                      $DEBUG_TEST"
  echo "    TEST_CASE (0 means all)         $TEST_CASE"
  echo "    VERBOSE                         $VERBOSE"
  echo "    CURL_CMD                        $CURL_CMD"
  echo "    FT_REQ_REMOTE_CLIENT_NODE       $FT_REQ_REMOTE_CLIENT_NODE"
  echo "  From YAML Files:"
  echo "    SERVER_POD_NAME                 $SERVER_POD_NAME"
  echo "    SERVER_HOST_POD_NAME            $SERVER_HOST_POD_NAME"
  echo "    CLIENT_POD_NAME_PREFIX          $CLIENT_POD_NAME_PREFIX"
  echo "    SERVER_POD_PORT                 $SERVER_POD_PORT"
  echo "    SERVER_HOST_POD_PORT            $SERVER_HOST_POD_PORT"
  echo "    NODEPORT_SVC_NAME               $NODEPORT_SVC_NAME"
  echo "    NODEPORT_HOST_SVC_NAME          $NODEPORT_HOST_SVC_NAME"
  echo "    NODEPORT_POD_PORT               $NODEPORT_POD_PORT"
  echo "    NODEPORT_HOST_PORT              $NODEPORT_HOST_PORT"
  echo "    POD_SERVER_STRING               $POD_SERVER_STRING"
  echo "    HOST_SERVER_STRING              $HOST_SERVER_STRING"
  echo "    EXTERNAL_SERVER_STRING          $EXTERNAL_SERVER_STRING"
  echo "  External Access:"
  echo "    EXTERNAL_IP                     $EXTERNAL_IP"
  echo "    EXTERNAL_URL                    $EXTERNAL_URL"
  echo "Queried Values:"
  echo "  Pod Backed:"
  echo "    SERVER_IP                       $SERVER_IP"
  echo "    SERVER_NODE                     $SERVER_NODE"
  echo "    LOCAL_CLIENT_NODE               $LOCAL_CLIENT_NODE"
  echo "    LOCAL_CLIENT_POD                $LOCAL_CLIENT_POD"
  echo "    REMOTE_CLIENT_NODE              $REMOTE_CLIENT_NODE"
  echo "    REMOTE_CLIENT_POD               $REMOTE_CLIENT_POD"
  echo "    NODEPORT_CLUSTER_IPV4           $NODEPORT_CLUSTER_IPV4"
  echo "    NODEPORT_ENDPOINT_IPV4          $NODEPORT_ENDPOINT_IPV4"
  echo "  Host backed:"
  echo "    SERVER_HOST_IP                  $SERVER_HOST_IP"
  echo "    SERVER_HOST_NODE                $SERVER_NODE"
  echo "    LOCAL_CLIENT_HOST_NODE          $LOCAL_CLIENT_NODE"
  echo "    LOCAL_CLIENT_HOST_POD           $LOCAL_CLIENT_HOST_POD"
  echo "    REMOTE_CLIENT_HOST_NODE         $REMOTE_CLIENT_NODE"
  echo "    REMOTE_CLIENT_HOST_POD          $REMOTE_CLIENT_HOST_POD"
  echo "    NODEPORT_HOST_CLUSTER_IPV4      $NODEPORT_HOST_CLUSTER_IPV4"
  echo "    NODEPORT_HOST_ENDPOINT_IPV4     $NODEPORT_HOST_ENDPOINT_IPV4"
  echo
}
echo
echo "Default/Override Values:"
echo "  Test Control:"
echo "    DEBUG_TEST                      $DEBUG_TEST"
echo "    TEST_CASE (0 means all)         $TEST_CASE"
echo "    VERBOSE                         $VERBOSE"
echo "    CURL_CMD                        $CURL_CMD"
echo "    FT_REQ_REMOTE_CLIENT_NODE       $FT_REQ_REMOTE_CLIENT_NODE"
echo "  From YAML Files:"
echo "    SERVER_POD_NAME                 $SERVER_POD_NAME"
echo "    SERVER_CLUSERIP_POD_NAME        $SERVER_CLUSTERIP_POD_NAME"
echo "    SERVER_NODEPORT_POD_NAME        $SERVER_NODEPORT_POD_NAME"
echo "    SERVER_HOST_POD_NAME            $SERVER_HOST_POD_NAME"
echo "    CLIENT_POD_NAME_PREFIX          $CLIENT_POD_NAME_PREFIX"
echo "    SERVER_POD_PORT                 $SERVER_POD_PORT"
echo "    SERVER_HOST_POD_PORT            $SERVER_HOST_POD_PORT"
echo "    CLUSTERIP_SVC_NAME              $CLUSTERIP_SVC_NAME"
echo "    NODEPORT_SVC_NAME               $NODEPORT_SVC_NAME"
echo "    NODEPORT_HOST_SVC_NAME          $NODEPORT_HOST_SVC_NAME"
echo "    NODEPORT_POD_PORT               $NODEPORT_POD_PORT"
echo "    NODEPORT_HOST_PORT              $NODEPORT_HOST_PORT"
echo "    POD_SERVER_STRING               $POD_SERVER_STRING"
echo "    HOST_SERVER_STRING              $HOST_SERVER_STRING"
echo "    EXTERNAL_SERVER_STRING          $EXTERNAL_SERVER_STRING"
echo "  External Access:"
echo "    EXTERNAL_IP                     $EXTERNAL_IP"
echo "    EXTERNAL_URL                    $EXTERNAL_URL"
echo "Queried Values:"
echo "  Pod Backed:"
echo "    SERVER_IP                       $SERVER_IP"
echo "    SERVER_NODE                     $SERVER_NODE"
echo "    LOCAL_CLIENT_NODE               $LOCAL_CLIENT_NODE"
echo "    LOCAL_CLIENT_POD                $LOCAL_CLIENT_POD"
echo "    REMOTE_CLIENT_NODE              $REMOTE_CLIENT_NODE"
echo "    REMOTE_CLIENT_POD               $REMOTE_CLIENT_POD"
echo "    CLUSTERIP_SERVICE_IPV4          $CLUSTERIP_SERVICE_IPV4"
echo "    NODEPORT_SERVICE_IPV4           $NODEPORT_SERVICE_IPV4"
echo "    NODEPORT_HOST_SVC_IPV4           $NODEPORT_HOST_SVC_IPV4"
echo "    NODEPORT_ENDPOINT_IPV4          $NODEPORT_ENDPOINT_IPV4"
echo "  Host backed:"
echo "    SERVER_HOST_IP                  $SERVER_HOST_IP"
echo "    SERVER_HOST_NODE                $SERVER_NODE"
echo "    LOCAL_CLIENT_HOST_NODE          $LOCAL_CLIENT_NODE"
echo "    LOCAL_CLIENT_HOST_POD           $LOCAL_CLIENT_HOST_POD"
echo "    REMOTE_CLIENT_HOST_NODE         $REMOTE_CLIENT_NODE"
echo "    REMOTE_CLIENT_HOST_POD          $REMOTE_CLIENT_HOST_POD"
echo "    NODEPORT_HOST_CLUSTER_IPV4      $NODEPORT_HOST_CLUSTER_IPV4"
echo "    NODEPORT_HOST_ENDPOINT_IPV4     $NODEPORT_HOST_ENDPOINT_IPV4"
echo


process-curl-output() {
  if [ "$VERBOSE" == true ]; then
    echo "${1}"
  fi
  echo "${1}" | grep -cq "${2}" && echo -e "${GREEN}SUCCESS${NC}\r\n" || echo -e "${RED}FAILED${NC}\r\n"
}

if [ ! -z "$1" ] ; then
  if [ "$1" == help ] || [ "$1" == "--help" ] ; then
    echo
    echo "This script uses ENV Variables to control test:"
    echo "  DEBUG_TEST                 - Run additional tests like ping or curl to port 8080"
    echo "                               instead of NodePort. Example:"
    echo "                                 DEBUG_TEST=true ./test.sh"
    echo "  TEST_CASE (0 means all)    - Run a single test. Example:"
    echo "                                 TEST_CASE=3 ./test.sh"
    echo "  VERBOSE                    - Command output is masked by default. Enable ping and curl"
    echo "                               output. Example:"
    echo "                                 VERBOSE=true ./test.sh"
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
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $LOCAL_CLIENT_POD -- ping $SERVER_IP -c 3"
    kubectl exec -it $LOCAL_CLIENT_POD -- ping $SERVER_IP -c 3
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$SERVER_IP:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$SERVER_IP:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  echo "*** 1-a: Pod to Pod (Same Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE -dst=$SERVER_POD_NAME -dst-port=$SERVER_POD_PORT -src=$LOCAL_CLIENT_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/pod2pod-same-node.txt
  
  echo "*** END OF TRACE (see ovn-traces/pod2pod-same-node.txt for full detail"
  echo

  echo
  echo "*** 1-b: Pod to Pod (Different Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_POD -- ping $SERVER_IP -c 3"
    kubectl exec -it $REMOTE_CLIENT_POD -- ping $SERVER_IP -c 3
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$SERVER_IP:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$SERVER_IP:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "*** 1-b: Pod to Pod (Different Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE -dst=$SERVER_POD_NAME -dst-port=$SERVER_POD_PORT -src=$REMOTE_CLIENT_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/pod2pod-diff-node.txt
  
  echo "*** END OF TRACE (see ovn-traces/pod2pod-diff-node.txt for full detail"
  echo
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 2 ]; then
  echo
  echo "FLOW 02: Pod -> Cluster IP Service traffic"
  echo "------------------------------------------"
  echo
  echo "*** 2-a: Pod -> Cluster IP Service traffic (Same Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $LOCAL_CLIENT_POD -- ping $CLUSTERIP_SERVICE_IPV4 -c 3"
    echo -e "${BLUE}ERROR - 100% packet loss - skipped for time${NC}"
    #kubectl exec -it $LOCAL_CLIENT_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3
    echo

    echo "DEBUG - END"
    echo
  fi
  
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$CLUSTERIP_SERVICE_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$CLUSTERIP_SERVICE_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  echo "*** 2-a:  Pod -> Cluster IP Service traffic (Same Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE  $SSL_ENABLE -service=$CLUSTERIP_SVC_NAME -dst-port=$SERVER_POD_PORT -src=$LOCAL_CLIENT_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/pod2clusterIPsvc-same-node.txt
  
  echo "*** END OF TRACE (see ovn-traces/pod2clusterIPsvc-same-node.txt for full detail"
  echo

  echo
  echo "*** 2-b: Pod -> Cluster IP Service traffic (Different Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_POD -- ping $CLUSTERIP_SERVICE_IPV4 -c 3"
    echo -e "${BLUE}ERROR - 100% packet loss - skipped for time${NC}"
    #kubectl exec -it $REMOTE_CLIENT_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3
    echo

    echo "DEBUG - END"
    echo  
  fi

  echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$CLUSTERIP_SERVICE_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$CLUSTERIP_SERVICE_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  echo "*** 2-b:  Pod -> Cluster IP Service traffic (Different Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE  $SSL_ENABLE -service=$CLUSTERIP_SVC_NAME -dst-port=$SERVER_POD_PORT -src=$REMOTE_CLIENT_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/pod2clusterIPsvc-diff-node.txt
  
  echo "*** END OF TRACE (see ovn-traces/pod2clusterIPsvc-diff-node.txt for full detail"
  echo
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 3 ]; then
  echo
  echo "FLOW 03: Pod -> NodePort Service traffic (pod/host backend)"
  echo "-----------------------------------------------------------"

  echo
  echo "*** 3-a: Pod -> NodePort Service traffic (pod backend - Same Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $LOCAL_CLIENT_POD -- ping $NODEPORT_ENDPOINT_IPV4 -c 3"
    kubectl exec -it $LOCAL_CLIENT_POD -- ping $NODEPORT_ENDPOINT_IPV4 -c 3
    echo

    echo "curl SvcClusterIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:SvcPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl HostIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$SERVER_HOST_IP:$NODEPORT_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$SERVER_HOST_IP:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  #echo -e "${BLUE}INVALID Command - Skip${NC}"
  #echo
  #TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl SvcName:SvcPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  echo "*** 3-a: Pod -> NodePort Service traffic (pod backend - Same Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE  $SSL_ENABLE -service=$NODEPORT_SVC_NAME -dst-port=$SERVER_POD_PORT -src=$LOCAL_CLIENT_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/pod2nodePortsvc-pod-backend-same-node.txt
  echo "*** END OF TRACE (see ovn-traces/pod2nodePortsvc-pod-backend-same-node.txt for full detail"
  echo

  echo
  echo "*** 3-b: Pod -> NodePort Service traffic (pod backend - Different Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_POD -- ping $NODEPORT_ENDPOINT_IPV4 -c 3"
    kubectl exec -it $REMOTE_CLIENT_POD -- ping $NODEPORT_ENDPOINT_IPV4 -c 3
    echo

    echo "curl SvcClusterIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

   echo "curl SvcClusterIP:SvcPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl HostIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$SERVER_HOST_IP:$NODEPORT_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$SERVER_HOST_IP:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  #echo -e "${BLUE}INVALID Command - Skip${NC}"
  #echo
  #TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl SvcName:SvcPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  echo "*** 3-b: Pod -> NodePort Service traffic (pod backend - different Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE  $SSL_ENABLE -service=$NODEPORT_SVC_NAME -dst-port=$SERVER_POD_PORT -src=$REMOTE_CLIENT_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/pod2nodePortsvc-pod-backend-diff-node.txt
  echo "*** END OF TRACE (see ovn-traces/pod2nodePortsvc-pod-backend-diff-node.txt for full detail"
  echo

  echo
  echo "*** 3-c: Pod -> NodePort Service traffic (host networked pod backend - Same Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $LOCAL_CLIENT_POD -- ping $NODEPORT_HOST_ENDPOINT_IPV4 -c 3"
    kubectl exec -it $LOCAL_CLIENT_POD -- ping $NODEPORT_HOST_ENDPOINT_IPV4 -c 3
    echo

    echo "curl SvcClusterIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:SvcPort"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_SVC_IPV4:$SERVER_HOST_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_SVC_IPV4:$SERVER_HOST_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl HostIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl SvcName:SvcPort"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
  echo

   echo "*** 3-c: Pod -> NodePort Service traffic (host networked pod backend - Same Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE  $SSL_ENABLE -service=$NODEPORT_HOST_SVC_NAME -dst-port=$SERVER_HOST_POD_PORT -src=$LOCAL_CLIENT_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/pod2nodePortsvc-host-backend-same-node.txt
  echo "*** END OF TRACE (see ovn-traces/pod2nodePortsvc-host-backend-same-node.txt for full detail"
  echo

  echo
  echo "*** 3-d: Pod -> NodePort Service traffic (host networked pod backend - Different Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_POD -- ping $NODEPORT_HOST_ENDPOINT_IPV4 -c 3"
    kubectl exec -it $REMOTE_CLIENT_POD -- ping $NODEPORT_HOST_ENDPOINT_IPV4 -c 3
    echo

    echo "curl SvcClusterIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:SvcPort"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_SVC_IPV4:$SERVER_HOST_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_SVC_IPV4:$SERVER_HOST_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl HostIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl SvcName:SvcPort"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
  echo

  echo "***  3-d: Pod -> NodePort Service traffic (host networked pod backend - Different Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE  $SSL_ENABLE -service=$NODEPORT_HOST_SVC_NAME -dst-port=$SERVER_HOST_POD_PORT -src=$REMOTE_CLIENT_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/pod2nodePortsvc-host-backend-diff-node.txt
  echo "*** END OF TRACE (see ovn-traces/pod2nodePortsvc-host-backend-diff-node.txt for full detail"
  echo
fi

if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 4 ]; then
  echo
  echo "FLOW 04: Pod/Host Pod -> External Network (egress traffic)"
  echo "----------------------------------------------------------"
  echo
  echo "*** 4-a: Pod -> External Network (egress traffic) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_POD -- ping $EXTERNAL_IP -c 3"
    kubectl exec -it $REMOTE_CLIENT_POD -- ping $EXTERNAL_IP -c 3
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD $EXTERNAL_URL"
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- $CURL_CMD $EXTERNAL_URL`
  process-curl-output "${TMP_OUTPUT}" "${EXTERNAL_SERVER_STRING}"
  
  echo "***  4-a: Pod -> External Network (egress traffic) TRACE ***"
   ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE $SSL_ENABLE -src=$REMOTE_CLIENT_POD -remotehost=$EXTERNAL_SERVER_STRING -kubeconfig=$KUBECONFIG 2> ovn-traces/pod2externalHost.txt
  echo "*** END OF TRACE (see ovn-traces/pod2externalHost.txt for full detail"
  echo
  
  echo

  echo
  echo "*** 4-b: Host Pod -> External Network (egress traffic) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- ping $EXTERNAL_IP -c 3"
    kubectl exec -it $REMOTE_CLIENT_HOST_POD -- ping $EXTERNAL_IP -c 3
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD $EXTERNAL_URL"
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD $EXTERNAL_URL`
  process-curl-output "${TMP_OUTPUT}" "${EXTERNAL_SERVER_STRING}"
  echo
fi

if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 5 ]; then
  echo
  echo "FLOW 05: Host Pod -> Cluster IP Service traffic (pod backend)"
  echo "---------------------------------------------------------"
  echo
  echo "*** 5-a: Host Pod -> Cluster IP Service traffic (pod backend - Same Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- ping $CLUSTERIP_SERVICE_IPV4 -c 3"
    #kubectl exec -it $LOCAL_CLIENT_HOST_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$CLUSTERIP_SERVICE_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$CLUSTERIP_SERVICE_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  echo "***  5-a: Host Pod -> Cluster IP Service traffic (pod backend - Same Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE  $SSL_ENABLE -service=$CLUSTERIP_SVC_NAME -dst-port=$SERVER_POD_PORT -src=$LOCAL_CLIENT_HOST_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/hostpod2clusterIPsvc-pod-backend-same-node.txt
  echo "*** END OF TRACE (see ovn-traces/pod2nodePortsvc-host-backend-diff-node.txt for full detail"
  
  echo

  echo
  echo "*** 5-b: Host Pod -> Cluster IP Service traffic (pod backend - Different Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3"
    #kubectl exec -it $REMOTE_CLIENT_HOST_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$CLUSTERIP_SERVICE_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$CLUSTERIP_SERVICE_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  echo "***  5-b: Host Pod -> Cluster IP Service traffic (pod backend - Different Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE  $SSL_ENABLE -service=$CLUSTERIP_SVC_NAME -dst-port=$SERVER_POD_PORT -src=$REMOTE_CLIENT_HOST_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/hostpod2clusterIPsvc-pod-backend-diff-node.txt
  echo "*** END OF TRACE (see ovn-traces/pod2nodePortsvc-host-backend-diff-node.txt for full detail"
  
  echo
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 6 ]; then
  echo
  echo "FLOW 06: Host Pod -> NodePort Service traffic (pod backend)"
  echo "-------------------------------------------------------"
  echo
  echo "*** 6-a: Host Pod -> NodePort Service traffic (pod backend - Same Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- ping $NODEPORT_ENDPOINT_IPV4 -c 3"
    kubectl exec -it $LOCAL_CLIENT_HOST_POD -- ping $NODEPORT_ENDPOINT_IPV4 -c 3
    echo

    echo "curl SvcClusterIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
    echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-node-v4; Unknown error${NC}"
    echo -e "${BLUE}Should this work?${NC}"
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl hostIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$SERVER_HOST_IP:$NODEPORT_POD_PORT/\""
  echo
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$SERVER_HOST_IP:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
  echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-node-v4; Unknown error${NC}"
  echo -e "${BLUE}Should this work? -- GOOD QUESTION${NC}"
  kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  echo "*** 6-a: Host Pod -> NodePort Service traffic (pod backend - Same Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE  $SSL_ENABLE -service=$NODEPORT_SVC_NAME -dst-port=$SERVER_POD_PORT -src=$LOCAL_CLIENT_HOST_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/hostpod2nodePortsvc-pod-backend-same-node.txt
  echo "*** END OF TRACE (see ovn-traces/hostpod2nodePortsvc-pod-backend-same-node.txt for full detail"
  
  echo

  echo
  echo "*** 6-b: Host Pod -> NodePort Service traffic (pod backend - Different Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- ping $NODEPORT_ENDPOINT_IPV4 -c 3"
    kubectl exec -it $REMOTE_CLIENT_HOST_POD -- ping $NODEPORT_ENDPOINT_IPV4 -c 3
    echo

    echo "curl SvcClusterIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
    echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-node-v4; Unknown error${NC}"
    echo -e "${BLUE}Should this work?${NC}"
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
    
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http:/$NODEPORT_SERVICE_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl hostIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$SERVER_HOST_IP:$NODEPORT_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
  echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-node-v4; Unknown error${NC}"
  echo -e "${BLUE}Should this work?${NC}"
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  
  echo "*** 6-b: Host Pod -> NodePort Service traffic (pod backend - Different Node) TRACE ***"
  ./ovnkube-trace -loglevel=5 -tcp -ovn-config-namespace=$OVN_K_NAMESPACE  $SSL_ENABLE -service=$NODEPORT_SVC_NAME -dst-port=$SERVER_POD_PORT -src=$REMOTE_CLIENT_HOST_POD -kubeconfig=$KUBECONFIG 2> ovn-traces/hostpod2nodePortsvc-pod-backend-diff-node.txt
  echo "*** END OF TRACE (see ovn-traces/hostpod2nodePortsvc-pod-backend-diff-node.txt for full detail"
  
  
  echo
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 7 ]; then
  echo
  echo "FLOW 07: Host Pod -> Cluster IP Service traffic (host networked pod backend)"
  echo "------------------------------------------------------------------------"
  echo
  echo "*** 7-a: Host Pod -> Cluster IP Service traffic (host networked pod backend - Same Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- ping $NODEPORT_HOST_CLUSTER_IPV4 -c 3"
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #kubectl exec -it $LOCAL_CLIENT_HOST_POD -- ping $NODEPORT_HOST_CLUSTER_IPV4 -c 3

    echo "DEBUG - END"
    echo
  fi

  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
  echo

  echo
  echo "*** 7-b: Host Pod -> Cluster IP Service traffic (host networked pod backend - Different Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- ping $NODEPORT_HOST_CLUSTER_IPV4 -c 3"
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #kubectl exec -it $REMOTE_CLIENT_HOST_POD -- ping $NODEPORT_HOST_CLUSTER_IPV4 -c 3

    echo "DEBUG - END"
    echo
  fi

  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
  echo
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 8 ]; then
  echo
  echo "FLOW 08: Host Pod -> NodePort Service traffic (host networked pod backend)"
  echo "----------------------------------------------------------------------"
  echo
  echo "*** 8-a: Host Pod -> NodePort Service traffic (host networked pod backend - Same Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- ping $NODEPORT_HOST_ENDPOINT_IPV4 -c 3"
    kubectl exec -it $LOCAL_CLIENT_HOST_POD -- ping $NODEPORT_HOST_ENDPOINT_IPV4 -c 3
    echo

    echo "curl SvcClusterIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""
    echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-host-node-v4; Unknown error${NC}"
    echo -e "${BLUE}ERROR - Should this work?${NC}"
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/\""
  echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-host-node-v4; Unknown error${NC}"
  echo -e "${BLUE}ERROR - Should this work?${NC}"
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
  echo

  echo
  echo "*** 8-b: Host Pod -> NodePort Service traffic (host networked pod backend - Different Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- ping $NODEPORT_HOST_ENDPOINT_IPV4 -c 3"
    kubectl exec -it $REMOTE_CLIENT_HOST_POD -- ping $NODEPORT_HOST_ENDPOINT_IPV4 -c 3
    echo

    echo "curl SvcClusterIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""
    echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-host-node-v4; Unknown error${NC}"
    echo -e "${BLUE}ERROR - Should this work?${NC}"
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD \"http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/\""
  echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-host-node-v4; Unknown error${NC}"
  echo -e "${BLUE}ERROR - Should this work?${NC}"
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- $CURL_CMD "http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
  echo
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 9 ]; then
  echo
  echo "FLOW 09: External Network Traffic -> NodePort/External IP Service (ingress traffic)"
  echo "-----------------------------------------------------------------------------------"
  echo
  echo "*** 9-a: External Network Traffic -> NodePort/External IP Service (ingress traffic - pod backend) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "ping $NODEPORT_ENDPOINT_IPV4 -c 3"
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #ping $NODEPORT_ENDPOINT_IPV4 -c 3

    echo "curl SvcClusterIP:PORT"
    echo "$CURL_CMD \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "$CURL_CMD \"http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/\""
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "$CURL_CMD \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
    #echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "$CURL_CMD \"http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "$CURL_CMD \"http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "$CURL_CMD \"http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  #echo

  echo
  echo "*** 9-b: External Network Traffic -> NodePort/External IP Service (ingress traffic - host backend) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "ping $NODEPORT_HOST_ENDPOINT_IPV4 -c 3"
    ping $NODEPORT_HOST_ENDPOINT_IPV4 -c 3
    echo

    echo "curl SvcClusterIP:PORT"
    echo "$CURL_CMD \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "$CURL_CMD \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/\""
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "$CURL_CMD \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "$CURL_CMD \"http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_HOST_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_HOST_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "$CURL_CMD \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "$CURL_CMD \"http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`$CURL_CMD "http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 10 ]; then
  echo
  echo "FLOW 10: External network traffic -> pods (multiple external gw traffic)"
  echo "------------------------------------------------------------------------"
  echo -e "${BLUE}NOT IMPLEMENTED${NC}"
  echo
fi


