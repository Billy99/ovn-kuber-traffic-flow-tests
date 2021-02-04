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

# From YAML Files
SERVER_POD_NAME=${SERVER_POD_NAME:-web-server-node-v4}
SERVER_HOST_POD_NAME=${SERVER_HOST_POD_NAME:-web-server-host-node-v4}
SERVER_POD_PORT=${SERVER_POD_PORT:-8080}
SERVER_HOST_POD_PORT=${SERVER_HOST_POD_PORT:-8081}
CLIENT_POD_NAME_PREFIX=${CLIENT_POD_NAME_PREFIX:-web-client-pod}
CLIENT_HOST_POD_NAME_PREFIX=${CLIENT_HOST_POD_NAME_PREFIX:-web-client-host}
NODEPORT_SVC_NAME=${NODEPORT_SVC_NAME:-my-web-service-node-v4}
NODEPORT_HOST_SVC_NAME=${NODEPORT_HOST_SVC_NAME:-my-web-service-host-node-v4}
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

LOCAL_CLIENT_POD=`kubectl get pods -o wide | grep $CLIENT_POD_NAME_PREFIX | grep $LOCAL_CLIENT_NODE | awk -F' ' '{print $1}'`
REMOTE_CLIENT_POD=`kubectl get pods -o wide | grep $CLIENT_POD_NAME_PREFIX | grep $REMOTE_CLIENT_NODE | awk -F' ' '{print $1}'`

NODEPORT_CLUSTER_IPV4=`kubectl get services | grep $NODEPORT_SVC_NAME | awk -F' ' '{print $3}'`
#NODEPORT_ENDPOINT_IPV4=`kubectl get endpoints | grep $NODEPORT_SVC_NAME | awk -F' ' '{print $2}'`
NODEPORT_ENDPOINT_IPV4=$SERVER_IP

# HOST POD Values
#

LOCAL_CLIENT_HOST_POD=`kubectl get pods -o wide | grep $CLIENT_HOST_POD_NAME_PREFIX | grep $LOCAL_CLIENT_NODE | awk -F' ' '{print $1}'`
REMOTE_CLIENT_HOST_POD=`kubectl get pods -o wide | grep $CLIENT_HOST_POD_NAME_PREFIX | grep $REMOTE_CLIENT_NODE | awk -F' ' '{print $1}'`

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
echo
echo "Default/Override Values:"
echo "  Test Control:"
echo "    DEBUG_TEST                      $DEBUG_TEST"
echo "    TEST_CASE (0 means all)         $TEST_CASE"
echo "    VERBOSE                         $VERBOSE"
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


process-curl-output() {
   if [ "$VERBOSE" == true ]; then
      echo "${1}"
   fi
   echo "${1}" | grep -cq "${2}" && echo -e "${GREEN}SUCCESS${NC}\r\n" || echo -e "${RED}FAILED${NC}\r\n"
}


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

  echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$SERVER_IP:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$SERVER_IP:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
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

  echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$SERVER_IP:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$SERVER_IP:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
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

    echo "kubectl exec -it $LOCAL_CLIENT_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3"
    echo -e "${BLUE}ERROR - 100% packet loss - skipped for time${NC}"
    #kubectl exec -it $LOCAL_CLIENT_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3
    echo

    echo "DEBUG - END"
    echo
  fi
  
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
  echo

  echo
  echo "*** 2-b: Pod -> Cluster IP Service traffic (Different Node) ***"
  if [ "$DEBUG_TEST" == true ]; then
    echo "DEBUG - BEGIN"
    echo

    echo "kubectl exec -it $REMOTE_CLIENT_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3"
    echo -e "${BLUE}ERROR - 100% packet loss - skipped for time${NC}"
    #kubectl exec -it $REMOTE_CLIENT_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3
    echo

    echo "DEBUG - END"
    echo  
  fi

  echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
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
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
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
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
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
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_POD -- curl \"http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_POD -- curl "http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
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
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl \"http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl "http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
  echo
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 4 ]; then
  echo
  echo "FLOW 04: Pod -> External Network (egress traffic)"
  echo "-------------------------------------------------"
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

  echo "kubectl exec -it $REMOTE_CLIENT_POD -- curl $EXTERNAL_URL"
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_POD -- curl $EXTERNAL_URL`
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

    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3"
    #kubectl exec -it $LOCAL_CLIENT_HOST_POD -- ping $NODEPORT_CLUSTER_IPV4 -c 3
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
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

  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
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
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
    echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-node-v4; Unknown error${NC}"
    echo -e "${BLUE}Should this work?${NC}"
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-node-v4; Unknown error${NC}"
  echo -e "${BLUE}Should this work?${NC}"
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
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
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
    echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-node-v4; Unknown error${NC}"
    echo -e "${BLUE}Should this work?${NC}"
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-node-v4; Unknown error${NC}"
  echo -e "${BLUE}Should this work?${NC}"
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
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

  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
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

  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
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
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""
    echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-host-node-v4; Unknown error${NC}"
    echo -e "${BLUE}ERROR - Should this work?${NC}"
    TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/\""
  echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-host-node-v4; Unknown error${NC}"
  echo -e "${BLUE}ERROR - Should this work?${NC}"
  TMP_OUTPUT=`kubectl exec -it $LOCAL_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/"`
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
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/\""
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""
    echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-host-node-v4; Unknown error${NC}"
    echo -e "${BLUE}ERROR - Should this work?${NC}"
    TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
    process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
    echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_CLUSTER_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl \"http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/\""
  echo -e "${BLUE}curl: (6) Could not resolve host: my-web-service-host-node-v4; Unknown error${NC}"
  echo -e "${BLUE}ERROR - Should this work?${NC}"
  TMP_OUTPUT=`kubectl exec -it $REMOTE_CLIENT_HOST_POD -- curl "http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/"`
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
    echo "curl \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/\""
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`curl "http://$NODEPORT_CLUSTER_IPV4:$SERVER_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "curl \"http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/\""
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`curl "http://$NODEPORT_ENDPOINT_IPV4:$SERVER_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "curl \"http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/\""
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`curl "http://$NODEPORT_SVC_NAME:$SERVER_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"
    #echo

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "curl \"http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`curl "http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "curl \"http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`curl "http://$NODEPORT_ENDPOINT_IPV4:$NODEPORT_POD_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "curl \"http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`curl "http://$NODEPORT_SVC_NAME:$NODEPORT_POD_PORT/"`
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
    echo "curl \"http://$NODEPORT_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/\""
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`curl "http://$NODEPORT_CLUSTER_IPV4:$SERVER_HOST_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

    echo "curl EndPointIP:PORT"
    echo "curl \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/\""
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`curl "http://$NODEPORT_HOST_ENDPOINT_IPV4:$SERVER_HOST_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "curl SvcName:PORT"
    echo "curl \"http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/\""    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo -e "${BLUE}INVALID Command - Skip${NC}"
    echo
    #TMP_OUTPUT=`curl "http://$NODEPORT_HOST_SVC_NAME:$SERVER_HOST_POD_PORT/"`
    #process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

    echo "DEBUG - END"
    echo
  fi

  echo "curl SvcClusterIP:NODEPORT"
  echo "curl \"http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_HOST_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`curl "http://$NODEPORT_CLUSTER_IPV4:$NODEPORT_HOST_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${POD_SERVER_STRING}"

  echo "curl EndPointIP:NODEPORT"
  echo "curl \"http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/\""
  TMP_OUTPUT=`curl "http://$NODEPORT_HOST_ENDPOINT_IPV4:$NODEPORT_HOST_PORT/"`
  process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"

  echo "curl SvcName:NODEPORT"
  echo "curl \"http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/\""
  echo -e "${BLUE}INVALID Command - Skip${NC}"
  echo
  #TMP_OUTPUT=`curl "http://$NODEPORT_HOST_SVC_NAME:$NODEPORT_HOST_PORT/"`
  #process-curl-output "${TMP_OUTPUT}" "${HOST_SERVER_STRING}"
fi


if [ "$TEST_CASE" == 0 ] || [ "$TEST_CASE" == 10 ]; then
  echo
  echo "FLOW 10: External network traffic -> pods (multiple external gw traffic)"
  echo "------------------------------------------------------------------------"
  echo -e "${BLUE}NOT IMPLEMENTED${NC}"
  echo
fi


