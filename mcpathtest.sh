#!/bin/bash

shopt -s expand_aliases

# Source the functions in utilities.sh
. utilities.sh

# Make sure kubectl is installed. Create an alias if not.
# This needs to be done before other files are sourced.
test_for_kubectl

COMMAND="test"

# Constants
MODE_FULL="FullMode"
MODE_CO="ClientOnlyMode"
MODE_NONE="None"

INTRA_VXLAN_IFACE="vx-submariner"
INTRA_VXLAN_VTEP_NETWORK_PREFIX="240"
INTER_VXLAN_IFACE="vxlan-tunnel"
INTER_VXLAN_VTEP_NETWORK_PREFIX="241"

FT_NAMESPACE=${FT_NAMESPACE:-flow-test}
FT_SVC_QUALIFIER=${FT_SVC_QUALIFIER:-".${FT_NAMESPACE}.svc.clusterset.local"}


FT_CO_CLUSTER=${FT_CO_CLUSTER:-""}
FT_FULL_CLUSTER=${FT_FULL_CLUSTER:-""}
TEST_PATH=${TEST_PATH:-0}
PRINT_DBG_CMDS=${PRINT_DBG_CMDS:-false}

# Source the functions in other files
. variables.sh
#. generate-yaml.sh
#. labels.sh
. process-cmds.sh
#. multi-cluster.sh


#
# Default values (possible to override)
#
SUBOPER_NAMESPACE=${SUBOPER_NAMESPACE:-submariner-operator}
GATEWAY_POD_NAME=${GATEWAY_POD_NAME:-submariner-gateway}

#
# Functions
#

printCluster() {
  local CLUSTER_CO_INDEX=$1
  local CLUSTER_FULL_INDEX=$2

  if [[ ! -z "${SUB_GW_BC_IPADDR[$CLUSTER_CO_INDEX]}" ]]; then
    GWB="GW-B"
  else
    GWB="    "
  fi
  if [[ ! -z "${SUB_GW_BC_IPADDR[$CLUSTER_FULL_INDEX]}" ]]; then
    GWC="GW-C"
  else
    GWC="    "
  fi

  echo
  echo "--------------------------------------------------------------"
  echo "                     ${CLUSTER_ARRAY[$coIndex]} --> ${CLUSTER_ARRAY[$fullIndex]}"
  echo "                     (Client)     (Server)"
  echo "--------------------------------------------------------------"
  echo
  if [[ -z "${FT_CLNT_X_POD_NAME[$CLUSTER_CO_INDEX]}" ]] && \
     [[ "${SUB_GW_AND_SERVER_OVERLAP[$CLUSTER_FULL_INDEX]}" == false ]]; then
    echo "                          (2)     (5)"
    echo "                  +--------+       +--------+"
    echo "                  | Clnt-Y |-------|        |"
    echo "                  |  GW-A  |       |  GW-D  |---+"
    echo "                  |        |---+ +-|        |   |   +--------+"
    echo "                  +--------+   | | +--------+   +---|        |"
    echo "                             +-|-+                  | Server |"
    echo "                  +--------+ | |   +--------+   +---|        |"
    echo "                  |        |-+ +---|        |   |   +--------+"
    echo "                  |  $GWB  |       |  $GWC  |---+"
    echo "                  |        |-------|        |"
    echo "                  +--------+       +--------+"
    echo "                          (3)     (4)"
  elif [[ -z "${FT_CLNT_X_POD_NAME[$CLUSTER_CO_INDEX]}" ]] && \
       [[ "${SUB_GW_AND_SERVER_OVERLAP[$CLUSTER_FULL_INDEX]}" == true ]]; then
    echo "                          (2)     (5)"
    echo "                  +--------+       +--------+"
    echo "                  |ClientY |-------|  Server|"
    echo "                  |  GW-A  |       |  GW-D  |"
    echo "                  |        |---+ +-|        |"
    echo "                  +--------+   | | +--------+"
    echo "                             +-|-+"
    echo "                  +--------+ | |   +--------+"
    echo "                  |        |-+ +---|        |"
    echo "                  |  $GWB  |       |  $GWC  |"
    echo "                  |        |-------|        |"
    echo "                  +--------+       +--------+"
    echo "                          (3)     (4)"
  elif [[ ! -z "${FT_CLNT_X_POD_NAME[$CLUSTER_CO_INDEX]}" ]] && \
       [[ "${SUB_GW_AND_SERVER_OVERLAP[$CLUSTER_FULL_INDEX]}" == false ]]; then
    echo "                          (2)     (5)"
    echo "                  +--------+       +--------+"
    echo "                  | Clnt-Y |-------|        |"
    echo "         (1)  +---|  GW-A  |       |  GW-D  |---+"
    echo " +--------+   |   |        |---+ +-|        |   |   +--------+"
    echo " |        |---+   +--------+   | | +--------+   +---|        |"
    echo " | Clnt-X |                  +-|-+                  | Server |"
    echo " |        |---+   +--------+ | |   +--------+   +---|        |"
    echo " +--------+   |   |        |-+ +---|        |   |   +--------+"
    echo "              +---|  $GWB  |       |  $GWC  |---+"
    echo "                  |        |-------|        |"
    echo "                  +--------+       +--------+"
    echo "                          (3)     (4)"
  elif [[ ! -z "${FT_CLNT_X_POD_NAME[$CLUSTER_CO_INDEX]}" ]] && \
       [[ "${SUB_GW_AND_SERVER_OVERLAP[$CLUSTER_FULL_INDEX]}" == true ]]; then
    echo "                          (2)     (5)"
    echo "                  +--------+       +--------+"
    echo "                  | Clnt-Y |-------|  Server|"
    echo "         (1)  +---|  GW-A  |       |  GW-D  |"
    echo " +--------+   |   |        |---+ +-|        |"
    echo " |        |---+   +--------+   | | +--------+"
    echo " | Clnt-X |                  +-|-+"
    echo " |        |---+   +--------+ | |   +--------+"
    echo " +--------+   |   |        |-+ +---|        |"
    echo "              +---|  $GWB  |       |  $GWC  |"
    echo "                  |        |-------|        |"
    echo "                  +--------+       +--------+"
    echo "                          (3)     (4)"
  else
    echo "Issue with comparison: FT_CLNT_X_POD_NAME[$CLUSTER_CO_INDEX]=${FT_CLNT_X_POD_NAME[$CLUSTER_CO_INDEX]} SUB_GW_AND_SERVER_OVERLAP[$CLUSTER_FULL_INDEX]=${SUB_GW_AND_SERVER_OVERLAP[$CLUSTER_FULL_INDEX]}"
  fi

  echo
  if [[ ! -z "${FT_CLNT_X_POD_NAME[$CLUSTER_CO_INDEX]}" ]]; then
    echo " Clnt-X: ${FT_CLNT_X_NODE_NAME[$CLUSTER_CO_INDEX]}: ${FT_CLNT_X_POD_NAME[$CLUSTER_CO_INDEX]} and ${FT_CLNT_X_HOST_POD_NAME[$CLUSTER_CO_INDEX]}"
  fi

  echo " Clnt-Y: ${FT_CLNT_Y_NODE_NAME[$CLUSTER_CO_INDEX]}: ${FT_CLNT_Y_POD_NAME[$CLUSTER_CO_INDEX]} and ${FT_CLNT_Y_HOST_POD_NAME[$CLUSTER_CO_INDEX]}"

  echo " GW-A:   ${SUB_GW_AD_NODE_NAME[$CLUSTER_CO_INDEX]} ${SUB_GW_AD_IPADDR[$CLUSTER_CO_INDEX]} ${SUB_GW_AD_TOOLS_POD_NAME[$CLUSTER_CO_INDEX]}"
  [ "$PRINT_DBG_CMDS" == true ] && [ ! -z "${SUB_GW_AD_NODE_NAME[$CLUSTER_CO_INDEX]}" ] && \
    echo "  docker exec -ti ${SUB_GW_AD_NODE_NAME[$CLUSTER_CO_INDEX]} /bin/bash"

  echo " GW-B:   ${SUB_GW_BC_NODE_NAME[$CLUSTER_CO_INDEX]} ${SUB_GW_BC_IPADDR[$CLUSTER_CO_INDEX]} ${SUB_GW_BC_TOOLS_POD_NAME[$CLUSTER_CO_INDEX]}"
  [ "$PRINT_DBG_CMDS" == true ] && [ ! -z "${SUB_GW_BC_NODE_NAME[$CLUSTER_CO_INDEX]}" ] && \
    echo "  docker exec -ti ${SUB_GW_BC_NODE_NAME[$CLUSTER_CO_INDEX]} /bin/bash"

  echo " GW-C:   ${SUB_GW_BC_NODE_NAME[$CLUSTER_FULL_INDEX]} ${SUB_GW_BC_IPADDR[$CLUSTER_FULL_INDEX]} ${SUB_GW_BC_TOOLS_POD_NAME[$CLUSTER_FULL_INDEX]}"
  [ "$PRINT_DBG_CMDS" == true ] && [ ! -z "${SUB_GW_BC_NODE_NAME[$CLUSTER_FULL_INDEX]}" ] && \
    echo "  docker exec -ti ${SUB_GW_BC_NODE_NAME[$CLUSTER_FULL_INDEX]} /bin/bash"

  if [[ "$SUB_GW_AND_SERVER_OVERLAP[$CLUSTER_FULL_INDEX]" == true ]]; then
    echo " GW-D:   ${SUB_GW_AD_NODE_NAME[$CLUSTER_FULL_INDEX]} ${SUB_GW_AD_IPADDR[$CLUSTER_FULL_INDEX]} ${SUB_GW_AD_TOOLS_POD_NAME[$CLUSTER_FULL_INDEX]} ${FT_SERVICE_POD_IP[$CLUSTER_FULL_INDEX]}:${FT_SERVICE_POD_PORT[$CLUSTER_FULL_INDEX]} ${FT_SERVICE_HOST_POD_IP[$CLUSTER_FULL_INDEX]}:${FT_SERVICE_HOST_POD_PORT[$CLUSTER_FULL_INDEX]}"
    [ "$PRINT_DBG_CMDS" == true ] && [ ! -z "${SUB_GW_AD_NODE_NAME[$CLUSTER_FULL_INDEX]}" ] && \
      echo "  docker exec -ti ${SUB_GW_AD_NODE_NAME[$CLUSTER_FULL_INDEX]} /bin/bash"
  else
    echo " GW-D:   ${SUB_GW_AD_NODE_NAME[$CLUSTER_FULL_INDEX]} ${SUB_GW_AD_IPADDR[$CLUSTER_FULL_INDEX]} ${SUB_GW_AD_TOOLS_POD_NAME[$CLUSTER_FULL_INDEX]}"
    [ "$PRINT_DBG_CMDS" == true ] && [ ! -z "${SUB_GW_AD_NODE_NAME[$CLUSTER_FULL_INDEX]}" ] && \
      echo "  docker exec -ti ${SUB_GW_AD_NODE_NAME[$CLUSTER_FULL_INDEX]} /bin/bash" &&
      echo "  apt-get update" &&
      echo "  apt-get install -y tcpdump" &&
      echo "  ip route list table all > iproutelist.orig" &&
      echo "  tcpdump -neep -i any host ${FT_SERVICE_POD_IP[$CLUSTER_FULL_INDEX]}" &&
    echo " Srvr:   SVC-Pod: ${FT_SERVICE_POD_IP[$CLUSTER_FULL_INDEX]}:${FT_SERVICE_POD_PORT[$CLUSTER_FULL_INDEX]}  SVC-Host: ${FT_SERVICE_HOST_POD_IP[$CLUSTER_FULL_INDEX]}:${FT_SERVICE_HOST_POD_PORT[$CLUSTER_FULL_INDEX]}"
  fi
  echo " CIDR:   ${FT_CIDR_SVC_OR_CLUSTER[$CLUSTER_CO_INDEX]} ${FT_CIDR_SVC_OR_CLUSTER[$CLUSTER_FULL_INDEX]}"
  echo " Globalnet=$GLOBALNET_FLAG Server/ClientOverlap=${SUB_GW_AND_SERVER_OVERLAP[$CLUSTER_FULL_INDEX]}"
  echo
}

getRouteParams() {
  local CLUSTER_CO_INDEX=$1
  local CLUSTER_FULL_INDEX=$2
  local LIST_NUM=$3

  case "${LIST_NUM}" in
    1)
      CLUSTER_INDEX="${CLUSTER_CO_INDEX}"
      TOOLS_POD_NAME="${FT_CLNT_X_TOOLS_POD_NAME[$CLUSTER_INDEX]}"
      CLUSTER_NODE="${FT_CLNT_X_NODE_NAME[$CLUSTER_INDEX]}"
      SERVICE_CIDR="${FT_CIDR_SVC_OR_CLUSTER[$CLUSTER_FULL_INDEX]}"
      ROUTE_TABLE="all"
      ;;
    2)
      CLUSTER_INDEX="${CLUSTER_CO_INDEX}"
      TOOLS_POD_NAME="${SUB_GW_AD_TOOLS_POD_NAME[$CLUSTER_INDEX]}"
      CLUSTER_NODE="${SUB_GW_AD_NODE_NAME[$CLUSTER_INDEX]}"
      SERVICE_CIDR="${FT_CIDR_SVC_OR_CLUSTER[$CLUSTER_FULL_INDEX]}"
      ROUTE_TABLE="100"
      ;;
    3)
      CLUSTER_INDEX="${CLUSTER_CO_INDEX}"
      TOOLS_POD_NAME="${SUB_GW_BC_TOOLS_POD_NAME[$CLUSTER_INDEX]}"
      CLUSTER_NODE="${SUB_GW_BC_NODE_NAME[$CLUSTER_INDEX]}"
      SERVICE_CIDR="${FT_CIDR_SVC_OR_CLUSTER[$CLUSTER_FULL_INDEX]}"
      ROUTE_TABLE="100"
      ;;
    4)
      CLUSTER_INDEX="${CLUSTER_FULL_INDEX}"
      TOOLS_POD_NAME="${SUB_GW_BC_TOOLS_POD_NAME[$CLUSTER_INDEX]}"
      CLUSTER_NODE="${SUB_GW_BC_NODE_NAME[$CLUSTER_INDEX]}"
      SERVICE_CIDR="${FT_CIDR_SVC_OR_CLUSTER[$CLUSTER_CO_INDEX]}"
      ROUTE_TABLE="100"
      ;;
    5)
      CLUSTER_INDEX="${CLUSTER_FULL_INDEX}"
      TOOLS_POD_NAME="${SUB_GW_AD_TOOLS_POD_NAME[$CLUSTER_INDEX]}"
      CLUSTER_NODE="${SUB_GW_AD_NODE_NAME[$CLUSTER_INDEX]}"
      SERVICE_CIDR="${FT_CIDR_SVC_OR_CLUSTER[$CLUSTER_CO_INDEX]}"
      ROUTE_TABLE="100"
      ;;
    *)
      CLUSTER_INDEX=""
      TOOLS_POD_NAME=""
      CLUSTER_NODE=""
      SERVICE_CIDR=""
      ROUTE_TABLE=""
      ;;
  esac

  if [[ ! -z "${CLUSTER_INDEX}" ]]; then
    kubectl config use-context "${CLUSTER_ARRAY[$CLUSTER_INDEX]}" &>/dev/null
  fi
}

getNexthopRoute() {
  local CLUSTER_CO_INDEX=$1
  local CLUSTER_FULL_INDEX=$2
  local LIST_NUM=$3
  declare -n ROUTE_LIST=$4

  getRouteParams "${CLUSTER_CO_INDEX}" "${CLUSTER_FULL_INDEX}" "${LIST_NUM}"

  [ "$FT_DEBUG" == true ] && echo "  ENTER: getNexthopRoute() for ${CLUSTER_ARRAY[$CLUSTER_INDEX]}:${CLUSTER_NODE} (${LIST_NUM})"

  CMD="ip route list table ${ROUTE_TABLE} | grep ${SERVICE_CIDR} -A 2"
  [ "$FT_DEBUG" == true ] && echo "   kubectl exec -ti -n ${FT_NAMESPACE} ${TOOLS_POD_NAME} -- /bin/sh -c \"${CMD}\""

  local TMP_ROUTE=$( kubectl exec -ti -n "${FT_NAMESPACE}" "${TOOLS_POD_NAME}" -- /bin/sh -c "${CMD}")
  TMP_ROUTE=${TMP_ROUTE//"pervasive"/}

  # Split line of the return string into array elements
  while IFS=$'\r\n' read -r line; do
    ROUTE_LIST+=("$line")
  done <<< "$TMP_ROUTE"

  for index in "${!ROUTE_LIST[@]}"
  do
    # Trim leading spaces and TABs
    ROUTE_LIST[$index]=$(echo ${ROUTE_LIST[$index]} | awk '{$1=$1};1')
    [ "$FT_DEBUG" == true ] && echo "   ROUTE_LIST_$LIST_NUM[$index]=${ROUTE_LIST[$index]}"
    #hex=$(xxd -pu <<< "${ROUTE_LIST[$index]}")
    #echo "$hex"
  done
}

setNexthopRoute() {
  local NEXT_HOP=$1
  shift
  local CLUSTER_CO_INDEX=$1
  shift
  local CLUSTER_FULL_INDEX=$1
  shift
  local LIST_NUM=$1
  shift
  local ROUTE_LIST=("$@")

  getRouteParams "${CLUSTER_CO_INDEX}" "${CLUSTER_FULL_INDEX}" "${LIST_NUM}"

  [ "$FT_DEBUG" == true ] && echo "  ENTER: setNexthopRoute() for ${CLUSTER_ARRAY[$CLUSTER_INDEX]}:${CLUSTER_NODE} (${LIST_NUM})"

  if [[ -z "${ROUTE_LIST[2]}" ]]; then
    echo "   Update route FAILED for ${CLUSTER_NODE} - Needs to have at least 2 Nexthop Groups"
    return
  fi

  if [[ "${ROUTE_LIST[1]}" == *"$INTRA_VXLAN_IFACE"* ]]; then
    NEXT_HOP=$(echo $NEXT_HOP | awk -F'.' -v PREFIX="$INTRA_VXLAN_VTEP_NETWORK_PREFIX" -v OFS="." '$1=PREFIX')
  elif [[ "${ROUTE_LIST[1]}" == *"$INTER_VXLAN_IFACE"* ]]; then
    NEXT_HOP=$(echo $NEXT_HOP | awk -F'.' -v PREFIX="$INTER_VXLAN_VTEP_NETWORK_PREFIX" -v OFS="." '$1=PREFIX')
  fi

  for i in "${!ROUTE_LIST[@]}"
  do
    if [[ "${ROUTE_LIST[$i]}" == *"$NEXT_HOP"* ]]; then
      if [[ -z "${ROUTE_TABLE}" ]] || [[ "${ROUTE_TABLE}" == "all" ]]; then
        TABLE_STR=""
      else
        TABLE_STR="table ${ROUTE_TABLE} "
      fi

      CMD="ip route replace ${TABLE_STR}${ROUTE_LIST[0]} ${ROUTE_LIST[$i]}"

      [ "$FT_DEBUG" == true ] && echo "   kubectl exec -ti -n ${FT_NAMESPACE} ${TOOLS_POD_NAME} -- /bin/sh -c \"${CMD}\""
      kubectl exec -ti -n "${FT_NAMESPACE}" "${TOOLS_POD_NAME}" -- /bin/sh -c "${CMD}"
      if [ "$?" == 1 ]; then
        echo "   Update route FAILED for ${CLUSTER_NODE} - Command failed"
      else
        [ "$FT_DEBUG" == true ] && echo "   Update route SUCCEEDED for ${CLUSTER_NODE}"
      fi
      return
    fi
  done

  echo "   Update route for ${CLUSTER_NODE} NOT run: NEXT_HOP=$NEXT_HOP"
  for index in "${!ROUTE_LIST[@]}"
  do
    echo "    ROUTE_LIST[$index]=${ROUTE_LIST[$index]}"
  done
}

restoreNexthopRoute() {
  local CLUSTER_CO_INDEX=$1
  shift
  local CLUSTER_FULL_INDEX=$1
  shift
  local LIST_NUM=$1
  shift
  local ROUTE_LIST=("$@")

  getRouteParams "${CLUSTER_CO_INDEX}" "${CLUSTER_FULL_INDEX}" "${LIST_NUM}"

  [ "$FT_DEBUG" == true ] && echo "  ENTER: restoreNexthopRoute() for ${CLUSTER_ARRAY[$CLUSTER_INDEX]}:${CLUSTER_NODE} (${LIST_NUM})"

  if [[ -z "${ROUTE_LIST[2]}" ]]; then
    echo "   Restore routes FAILED for ${CLUSTER_NODE} - Needs to have at least 2 Nexthop Groups"
    return
  fi

  CMD="ip route replace"
  if [[ ! -z "${ROUTE_TABLE}" ]] && [[ "${ROUTE_TABLE}" != "all" ]]; then
    CMD+=" table ${ROUTE_TABLE}"
  fi
  for index in "${!ROUTE_LIST[@]}"
  do
    CMD+=" ${ROUTE_LIST[$index]}"
  done


  [ "$FT_DEBUG" == true ] && echo "   kubectl exec -ti -n ${FT_NAMESPACE} ${TOOLS_POD_NAME} -- /bin/sh -c \"${CMD}\""
  kubectl exec -ti -n "${FT_NAMESPACE}" "${TOOLS_POD_NAME}" -- /bin/sh -c "${CMD}"
  if [ "$?" == 1 ]; then
    echo "   Restore routes FAILED for ${CLUSTER_NODE} - Command failed"
  else
    [ "$FT_DEBUG" == true ] && echo "   Restore routes SUCCEEDED for ${CLUSTER_NODE}"
  fi
}

testClntX() {
  local CLUSTER_CO_INDEX=$1
  local CLUSTER_FULL_INDEX=$2
  local FILENAME=$3

  kubectl config use-context "${CLUSTER_ARRAY[$CLUSTER_CO_INDEX]}" &>/dev/null

  TEST_CLIENT_NODE="${FT_CLNT_X_NODE_NAME[$CLUSTER_CO_INDEX]}"
  TEST_FILENAME="${FILENAME}"

  echo "curl SvcClusterIP:SvcPORT (Pod Backend)"
  TEST_SERVER_RSP=$POD_SERVER_STRING
  TEST_CLIENT_POD="${FT_CLNT_X_POD_NAME[$CLUSTER_CO_INDEX]}"
  TEST_SERVER_HTTP_DST="${FT_SERVICE_POD_IP[$CLUSTER_FULL_INDEX]}"
  TEST_SERVER_HTTP_DST_PORT="${FT_SERVICE_POD_PORT[$CLUSTER_FULL_INDEX]}"
  process-curl

  echo "curl SvcClusterIP:SvcPORT (Host Backend)"
  TEST_SERVER_RSP=$HOST_SERVER_STRING
  TEST_CLIENT_POD="${FT_CLNT_X_HOST_POD_NAME[$CLUSTER_CO_INDEX]}"
  TEST_SERVER_HTTP_DST="${FT_SERVICE_HOST_POD_IP[$CLUSTER_FULL_INDEX]}"
  TEST_SERVER_HTTP_DST_PORT="${FT_SERVICE_HOST_POD_PORT[$CLUSTER_FULL_INDEX]}"
  process-curl
}

testClntY() {
  local CLUSTER_CO_INDEX=$1
  local CLUSTER_FULL_INDEX=$2
  local FILENAME=$3

  kubectl config use-context "${CLUSTER_ARRAY[$CLUSTER_CO_INDEX]}" &>/dev/null

  TEST_CLIENT_NODE="${FT_CLNT_Y_NODE_NAME[$CLUSTER_CO_INDEX]}"
  TEST_FILENAME="${FILENAME}"

  echo "curl SvcClusterIP:SvcPORT (Pod Backend)"
  TEST_SERVER_RSP=$POD_SERVER_STRING
  TEST_CLIENT_POD="${FT_CLNT_Y_POD_NAME[$CLUSTER_CO_INDEX]}"
  TEST_SERVER_HTTP_DST="${FT_SERVICE_POD_IP[$CLUSTER_FULL_INDEX]}"
  TEST_SERVER_HTTP_DST_PORT="${FT_SERVICE_POD_PORT[$CLUSTER_FULL_INDEX]}"
  process-curl

  echo "curl SvcClusterIP:SvcPORT (Host Backend)"
  TEST_SERVER_RSP=$HOST_SERVER_STRING
  TEST_CLIENT_POD="${FT_CLNT_Y_HOST_POD_NAME[$CLUSTER_CO_INDEX]}"
  TEST_SERVER_HTTP_DST="${FT_SERVICE_HOST_POD_IP[$CLUSTER_FULL_INDEX]}"
  TEST_SERVER_HTTP_DST_PORT="${FT_SERVICE_HOST_POD_PORT[$CLUSTER_FULL_INDEX]}"
  process-curl
}

# Save Context to restore when done.
ORIG_CONTEXT=$(kubectl config current-context)

# Retrieve all the managed clusters
CLUSTER_ARRAY=($(kubectl config get-contexts --no-headers=true | awk -F' ' '{print $3}'))
GLOBALNET_FLAG=false


echo
echo "----------------------"
echo "Analyzing Clusters"
echo "----------------------"
echo
echo "Looping through Cluster List Analyzing ($CLUSTER_LEN entries):"
for i in "${!CLUSTER_ARRAY[@]}"
do
  echo " Analyzing Cluster $((i+1)): ${CLUSTER_ARRAY[$i]}"
  kubectl config use-context ${CLUSTER_ARRAY[$i]} &>/dev/null
  # Get Globalnet State. Test for Broker, if found, then see if `globalnetEnabled` is set.
  BROKER_OUTPUT=`kubectl get namespaces --no-headers=true | grep -c "submariner-k8s-broker"`
  if [[ "$BROKER_OUTPUT" == 1 ]]; then
    echo "  Broker is on ${CLUSTER_ARRAY[$i]}"
    BROKER_OUTPUT=`kubectl get broker -n submariner-k8s-broker submariner-broker -o jsonpath='{.spec.globalnetEnabled}'`
    if [[ "$BROKER_OUTPUT" == "true" ]]; then
      GLOBALNET_FLAG=true
      echo "   Setting Globalnet flag to true"
    else
      echo "   Leaving Globalnet flag as false"
    fi
  else
    echo "  Broker not on ${CLUSTER_ARRAY[$i]}"
  fi

  CLUSTER_MODE[$i]=$MODE_NONE

  # To see if Flow-Test deployed on Cluster
  kubectl get --no-headers=true namespaces ${FT_NAMESPACE} &>/dev/null
  if [ "$?" == 0 ] ; then
    # CO
    #  Loop through all nodes
    #    Find Client Name of Non-Gateway Node (If exists)
    #      StandaloneClient TorF
    #    Find Client Name of Gateway Node
    #    Find IP of all Gateway Node

    # FULL
    #  Loop through all nodes
    #    Find IP of all Gateway Node
    #    Find IP of Server Node
    #      StandaloneServer TorF

    # Look for Host backer Server pod, in Client Only it shouldn't be there
    TEST_SERVER=$(kubectl get pods -n ${FT_NAMESPACE} | grep -o "$HTTP_SERVER_HOST_POD_NAME")
    if [ -z "${TEST_SERVER}" ]; then
      CLUSTER_MODE[$i]=$MODE_CO

      # Collect the Flow-Test Client Nodes
      TMP_OUTPUT=$(kubectl get pods -n ${FT_NAMESPACE} --selector=name=${CLIENT_POD_NAME_PREFIX} -o jsonpath='{range .items[*]}{@.metadata.name}{" "}{@.status.podIP}{" "}{@.spec.nodeName}{"\n"}{end}')
      TMP_CLNT_POD_NAME_LIST=( $(echo "${TMP_OUTPUT}" | awk -F' ' '{print $1}') )
      #TMP_CLNT_POD_IP_LIST=( $(echo "${TMP_OUTPUT}" |  awk -F' ' '{print $2}') )
      TMP_CLNT_POD_NODE_LIST=( $(echo "${TMP_OUTPUT}" | awk -F' ' '{print $3}') )

      TMP_OUTPUT=$(kubectl get pods -n ${FT_NAMESPACE} --selector=name=${CLIENT_HOST_POD_NAME_PREFIX} -o jsonpath='{range .items[*]}{@.metadata.name}{" "}{@.status.podIP}{" "}{@.spec.nodeName}{"\n"}{end}')
      TMP_CLNT_HOST_POD_NAME_LIST=( $(echo "${TMP_OUTPUT}" | awk -F' ' '{print $1}') )
      #TMP_CLNT_HOST_POD_IP_LIST=( $(echo "${TMP_OUTPUT}" |  awk -F' ' '{print $2}') )
      TMP_CLNT_HOST_POD_NODE_LIST=( $(echo "${TMP_OUTPUT}" | awk -F' ' '{print $3}') )
    else
      CLUSTER_MODE[$i]=$MODE_FULL

      TMP_OUTPUT=$(kubectl get pods -n ${FT_NAMESPACE} --selector=pod-name=${HTTP_SERVER_HOST_POD_NAME} -o jsonpath='{range .items[*]}{@.spec.nodeName}{"\n"}{end}')
      TMP_SERVER_NODE_LIST=( $(echo "${TMP_OUTPUT}" | awk -F' ' '{print $1}') )
    fi

    # Collect the Gateway Nodes
    TMP_OUTPUT=$(kubectl get pods -n ${SUBOPER_NAMESPACE} --selector=app=${GATEWAY_POD_NAME} -o jsonpath='{range .items[*]}{@.metadata.name}{" "}{@.status.podIP}{" "}{@.spec.nodeName}{"\n"}{end}')
    TMP_GATEWAY_NAME_LIST=( $(echo "${TMP_OUTPUT}" | awk -F' ' '{print $1}') )
    TMP_GATEWAY_IP_LIST=( $(echo "${TMP_OUTPUT}" |  awk -F' ' '{print $2}') )
    TMP_GATEWAY_NODE_LIST=( $(echo "${TMP_OUTPUT}" | awk -F' ' '{print $3}') )

    # Collect the Tool Pods
    TMP_OUTPUT=$(kubectl get pods -n ${FT_NAMESPACE} --selector=app=${FT_TOOLS_POD_NAME} -o jsonpath='{range .items[*]}{@.metadata.name}{" "}{@.spec.nodeName}{"\n"}{end}')
    TMP_TOOLS_NAME_LIST=( $(echo "${TMP_OUTPUT}" | awk -F' ' '{print $1}') )
    TMP_TOOLS_NODE_LIST=( $(echo "${TMP_OUTPUT}" | awk -F' ' '{print $2}') )

    #FT_CLNT_X_POD_NAME[$i]=
    #FT_CLNT_X_NODE_NAME[$i]=
    #FT_CLNT_X_HOST_POD_NAME[$i]=
    #FT_CLNT_X_TOOLS_POD_NAME[$i]=
    #FT_CLNT_Y_POD_NAME[$i]=
    #FT_CLNT_Y_HOST_POD_NAME[$i]=
    #FT_CLNT_Y_NODE_NAME[$i]=

    #FT_SERVICE_POD_IP[$i]=
    #FT_SERVICE_POD_PORT[$i]=
    #FT_SERVICE_HOST_POD_IP[$i]=
    #FT_SERVICE_HOST_POD_PORT[$i]=
    #FT_SERVER_NODE_NAME[$i]=
    #FT_CIDR_SVC_OR_CLUSTER[$i]=

    SUB_GW_AND_SERVER_OVERLAP[$i]=false
    GWD_SVR="GW-D -> Svr"
    SVR_GWD="Svr -> GW-D"
    #SUB_GW_AD_NODE_NAME[$i]=
    #SUB_GW_BC_NODE_NAME[$i]=
    #SUB_GW_AD_IPADDR[$i]=
    #SUB_GW_BC_IPADDR[$i]=
    #SUB_GW_AD_TOOLS_POD_NAME[$i]=
    #SUB_GW_BC_TOOLS_NODE_NAME[$i]=

    # Loop through the Gateway nodes
    if [[ "${CLUSTER_MODE[$i]}" == $MODE_CO ]]; then
      if [[ "$FT_DEBUG" == true ]]; then
        echo "  Setting up CO Mode"
        echo "    Loop through Client nodes and find one Client on the Gateway and"
        echo "    and save as GW and find one Client if it exists not on Gateway and"
        echo "    save as NOGW."
      fi

      for clientNodeIndex in "${!TMP_CLNT_POD_NODE_LIST[@]}"
      do
        ON_GW_FLAG=false
        for gatewayNodeIndex in "${!TMP_GATEWAY_NODE_LIST[@]}"
        do
          # Regular Pod (non-host backed)
          if [[ "${TMP_CLNT_POD_NODE_LIST[$clientNodeIndex]}" == "${TMP_GATEWAY_NODE_LIST[$gatewayNodeIndex]}" ]]; then
            ON_GW_FLAG=true

            if [[ -z "${FT_CLNT_Y_POD_NAME[$i]}" ]]; then
              [ "$FT_DEBUG" == true ] && echo "     GW: Setting Client ${TMP_CLNT_POD_NAME_LIST[$clientNodeIndex]} and Gateway ${TMP_GATEWAY_NAME_LIST[$gatewayNodeIndex]} overlap"
              FT_CLNT_Y_NODE_NAME[$i]=${TMP_CLNT_POD_NODE_LIST[$clientNodeIndex]}
              FT_CLNT_Y_POD_NAME[$i]=${TMP_CLNT_POD_NAME_LIST[$clientNodeIndex]}
              SUB_GW_AD_NODE_NAME[$i]=${TMP_GATEWAY_NODE_LIST[$gatewayNodeIndex]}
              SUB_GW_AD_IPADDR[$i]=${TMP_GATEWAY_IP_LIST[$gatewayNodeIndex]}
            else
              SUB_GW_BC_NODE_NAME[$i]=${TMP_GATEWAY_NODE_LIST[$gatewayNodeIndex]}
              SUB_GW_BC_IPADDR[$i]=${TMP_GATEWAY_IP_LIST[$gatewayNodeIndex]}
            fi
          fi
        done

        if [[ "${ON_GW_FLAG}" == false ]]; then
          if [[ ! -z "${FT_CLNT_X_POD_NAME[$i]}" ]]; then
            [ "$FT_DEBUG" == true ] && echo "     NO-GW: NO-GW Client already set to ${FT_CLNT_X_POD_NAME[$i]}"
          else
            [ "$FT_DEBUG" == true ] && echo "     NO-GW: Setting Client ${TMP_CLNT_POD_NAME_LIST[$clientNodeIndex]} as non-Gateway"
            FT_CLNT_X_NODE_NAME[$i]=${TMP_CLNT_POD_NODE_LIST[$clientNodeIndex]}
            FT_CLNT_X_POD_NAME[$i]=${TMP_CLNT_POD_NAME_LIST[$clientNodeIndex]}
          fi
        fi
      done

      # Set Host-Backed Pods to the same nodes
      for clientNodeIndex in "${!TMP_CLNT_HOST_POD_NODE_LIST[@]}"
      do
        if [[ "${TMP_CLNT_HOST_POD_NODE_LIST[$clientNodeIndex]}" == "${FT_CLNT_Y_NODE_NAME[$i]}" ]]; then
          FT_CLNT_Y_HOST_POD_NAME[$i]=${TMP_CLNT_HOST_POD_NAME_LIST[$clientNodeIndex]}
        elif [[ "${TMP_CLNT_HOST_POD_NODE_LIST[$clientNodeIndex]}" == "${FT_CLNT_X_NODE_NAME[$i]}" ]]; then
          FT_CLNT_X_HOST_POD_NAME[$i]=${TMP_CLNT_HOST_POD_NAME_LIST[$clientNodeIndex]}
        fi
      done

      FT_CIDR_SVC_OR_CLUSTER[$i]=$(kubectl get clusters --no-headers=true -n ${SUBOPER_NAMESPACE} ${CLUSTER_ARRAY[$i]} -o jsonpath='{.spec.cluster_cidr}' | awk -F'\"' '{print $2}')
    else
      if [[ "$FT_DEBUG" == true ]]; then
        echo "  Setting up FULL Mode"
        echo "    Loop through Gateway nodes and find Server/Gateway overlap if it"
        echo "    exists and save as AorD. Save non-overlap as BorC."
      fi

      for gatewayNodeIndex in "${!TMP_GATEWAY_NODE_LIST[@]}"
      do
        for serverNode in "${TMP_SERVER_NODE_LIST[@]}"
        do
          if [[ "${serverNode}" == "${TMP_GATEWAY_NODE_LIST[$gatewayNodeIndex]}" ]]; then
            [ "$FT_DEBUG" == true ] && echo "     AorD: Server and Gateway ${TMP_GATEWAY_NAME_LIST[$gatewayNodeIndex]} overlap"
            SUB_GW_AND_SERVER_OVERLAP[$i]=true
            GWD_SVR="GW-D/Svr"
            SVR_GWD="Svr/GW-D"
            SUB_GW_AD_NODE_NAME[$i]=${TMP_GATEWAY_NODE_LIST[$gatewayNodeIndex]}
            SUB_GW_AD_IPADDR[$i]=${TMP_GATEWAY_IP_LIST[$gatewayNodeIndex]}
          elif [[ -z "${SUB_GW_BC_NODE_NAME[$gatewayNodeIndex]}" ]] && [[ ${#TMP_GATEWAY_NODE_LIST[@]} > 1 ]]; then
            [ "$FT_DEBUG" == true ] && echo "     BorC: Setting ${TMP_GATEWAY_NAME_LIST[$gatewayNodeIndex]} to SUB_GW_BC_NODE_NAME"
            SUB_GW_BC_NODE_NAME[$i]=${TMP_GATEWAY_NODE_LIST[$gatewayNodeIndex]}
            SUB_GW_BC_IPADDR[$i]=${TMP_GATEWAY_IP_LIST[$gatewayNodeIndex]}
          else
            if [[ -z "${SUB_GW_AD_NODE_NAME[$i]}" ]]; then
              [ "$FT_DEBUG" == true ] && echo "     AorD: Setting ${TMP_GATEWAY_NAME_LIST[$gatewayNodeIndex]} to SUB_GW_AD_NODE_NAME"
              SUB_GW_AD_NODE_NAME[$i]=${TMP_GATEWAY_NODE_LIST[$gatewayNodeIndex]}
              SUB_GW_AD_IPADDR[$i]=${TMP_GATEWAY_IP_LIST[$gatewayNodeIndex]}
            else
              [ "$FT_DEBUG" == true ] && echo "     BorC: AorD already set so setting ${TMP_GATEWAY_NAME_LIST[$gatewayNodeIndex]} to SUB_GW_BC_NODE_NAME"
              SUB_GW_BC_NODE_NAME[$i]=${TMP_GATEWAY_NODE_LIST[$gatewayNodeIndex]}
              SUB_GW_BC_IPADDR[$i]=${TMP_GATEWAY_IP_LIST[$gatewayNodeIndex]}
            fi
          fi
          FT_SERVER_NODE_NAME[$i]="${serverNode}"
        done
      done

      if [[ "${GLOBALNET_FLAG}" == true ]]; then
        FT_CIDR_SVC_OR_CLUSTER[$i]=$(kubectl get clusters --no-headers=true -n ${SUBOPER_NAMESPACE} ${CLUSTER_ARRAY[$i]} -o jsonpath='{.spec.global_cidr}' | awk -F'\"' '{print $2}')
      else
        FT_CIDR_SVC_OR_CLUSTER[$i]=$(kubectl get clusters --no-headers=true -n ${SUBOPER_NAMESPACE} ${CLUSTER_ARRAY[$i]} -o jsonpath='{.spec.service_cidr}' | awk -F'\"' '{print $2}')
      fi

      TMP_OUTPUT=$(kubectl get serviceimports --no-headers=true -n ${SUBOPER_NAMESPACE} ${HTTP_CLUSTERIP_POD_SVC_NAME}-${FT_NAMESPACE}-${CLUSTER_ARRAY[$i]} -o jsonpath='{range .items[*]}{@.spec.ips}{" "}{@.spec.ports[*].port}{"\n"}')
      FT_SERVICE_POD_IP[$i]=$(echo "${TMP_OUTPUT}" | awk -F' ' '{print $1}' | awk -F'\"' '{print $2}')
      FT_SERVICE_POD_PORT[$i]=$(echo "${TMP_OUTPUT}" | awk -F' ' '{print $2}')

      TMP_OUTPUT=$(kubectl get serviceimports --no-headers=true -n ${SUBOPER_NAMESPACE} ${HTTP_CLUSTERIP_HOST_SVC_NAME}-${FT_NAMESPACE}-${CLUSTER_ARRAY[$i]} -o jsonpath='{range .items[*]}{@.spec.ips}{" "}{@.spec.ports[*].port}{"\n"}')
      FT_SERVICE_HOST_POD_IP[$i]=$(echo "${TMP_OUTPUT}" | awk -F' ' '{print $1}' | awk -F'\"' '{print $2}')
      FT_SERVICE_HOST_POD_PORT[$i]=$(echo "${TMP_OUTPUT}" | awk -F' ' '{print $2}')
    fi

    for toolsNodeIndex in "${!TMP_TOOLS_NODE_LIST[@]}"
    do
      if [[ "${TMP_TOOLS_NODE_LIST[$toolsNodeIndex]}" == "${FT_CLNT_X_NODE_NAME[$i]}" ]]; then
        FT_CLNT_X_TOOLS_POD_NAME[$i]="${TMP_TOOLS_NAME_LIST[$toolsNodeIndex]}"
        [ "$FT_DEBUG" == true ] && echo "     ClntX: Setting ${FT_CLNT_X_TOOLS_POD_NAME[$i]} to SUB_GW_BC_TOOLS_POD_NAME for node ${SUB_GW_BC_NODE_NAME[$i]}"
      fi
      if [[ "${TMP_TOOLS_NODE_LIST[$toolsNodeIndex]}" == "${SUB_GW_AD_NODE_NAME[$i]}" ]]; then
        SUB_GW_AD_TOOLS_POD_NAME[$i]="${TMP_TOOLS_NAME_LIST[$toolsNodeIndex]}"
        [ "$FT_DEBUG" == true ] && echo "     AorD: Setting ${SUB_GW_AD_TOOLS_POD_NAME[$i]} to SUB_GW_AD_TOOLS_POD_NAME for node ${SUB_GW_AD_NODE_NAME[$i]}"
      fi
      if [[ "${TMP_TOOLS_NODE_LIST[$toolsNodeIndex]}" == "${SUB_GW_BC_NODE_NAME[$i]}" ]]; then
        SUB_GW_BC_TOOLS_POD_NAME[$i]="${TMP_TOOLS_NAME_LIST[$toolsNodeIndex]}"
        [ "$FT_DEBUG" == true ] && echo "     BorC: Setting ${SUB_GW_BC_TOOLS_POD_NAME[$i]} to SUB_GW_BC_TOOLS_POD_NAME for node ${SUB_GW_BC_NODE_NAME[$i]}"
      fi
    done
  else
    echo "  Flow-Test not deployed on Cluster ${CLUSTER_ARRAY[$i]}"
  fi
done


echo
echo "Looping through Cluster List, Test \"Client Only\" Clusters:"
for coIndex in "${!CLUSTER_ARRAY[@]}"
do
  if [ "${CLUSTER_MODE[$coIndex]}" == $MODE_CO ]; then
    if [[ ! -z "${FT_CO_CLUSTER}" ]] && [[ "${FT_CO_CLUSTER}" != "${CLUSTER_ARRAY[$coIndex]}" ]]; then
      echo "FT_CO_CLUSTER=${FT_CO_CLUSTER} so skipping over ${CLUSTER_ARRAY[$coIndex]}"
      continue
    fi

    #
    # From here to the end of loop, ping-ponging between CO and FULL Clusters for kubectl calls.
    # So must set the context before running kubectl commands, mainly in getNexthopRoute(),
    # setNexthopRoute() and restoreNexthopRoute().
    #   kubectl config use-context ${CLUSTER_ARRAY[$coIndex]} &>/dev/null
    #

    for fullIndex in "${!CLUSTER_ARRAY[@]}"
    do
      if [ "${CLUSTER_MODE[$fullIndex]}" == $MODE_FULL ]; then

        if [[ ! -z "${FT_FULL_CLUSTER}" ]] && [[ "${FT_FULL_CLUSTER}" != "${CLUSTER_ARRAY[$fullIndex]}" ]]; then
          echo "FT_FULL_CLUSTER=${FT_FULL_CLUSTER} so skipping over ${CLUSTER_ARRAY[$fullIndex]}"
          continue
        fi

        ROUTE_LIST_1=()
        ROUTE_LIST_2=()
        ROUTE_LIST_3=()
        ROUTE_LIST_4=()
        ROUTE_LIST_5=()

        printCluster ${coIndex} ${fullIndex}

        if [[ ! -z "${SUB_GW_BC_NODE_NAME[$fullIndex]}" ]]; then
          # If GW-C exists, then get routes (2) from GW-A
          getNexthopRoute "${coIndex}" "${fullIndex}" "2" ROUTE_LIST_2
        fi

        if [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]]; then
          # If GW-B exists, then get routes (5) from GW-D
          getNexthopRoute "${coIndex}" "${fullIndex}" "5" ROUTE_LIST_5

          if [[ ! -z "${FT_CLNT_X_NODE_NAME[$coIndex]}" ]]; then
            # If GW-B and Clnt-X exists, then get routes (1) from Clnt-X
            getNexthopRoute "${coIndex}" "${fullIndex}" "1" ROUTE_LIST_1
          fi

          if [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]]; then
            # If GW-B and GW-C, then get routes (3) from GW-B
            getNexthopRoute "${coIndex}" "${fullIndex}" "3" ROUTE_LIST_3

            # If GW-B and GW-C, then get routes (4) from GW-C
            getNexthopRoute "${coIndex}" "${fullIndex}" "4" ROUTE_LIST_4
          fi
        fi

        # Common Test Settings
        MY_CLUSTER="${CLUSTER_ARRAY[$coIndex]}"
        TEST_SERVER_CLUSTER="${CLUSTER_ARRAY[$fullIndex]}"
        TEST_SERVER_NODE="${FT_SERVER_NODE_NAME[$fullIndex]}"

        if [ "$TEST_PATH" == 0 ] || [ "$TEST_PATH" == 1 ]; then
          echo
          echo "PATH 01: A-D -- D-A"
          echo "-------------------"
          # Set (1) to point to GW-A (if GW-B and Clnt-X exists)
          # Set (2) to point to GW-D (if GW-C exists)
          #     (3) not set yet
          #     (4) not set yet
          # Set (5) to point to GW-A (if GW-B exists)

          # Set (2) to point to GW-D (if GW-C exists)
          if [[ ! -z "${SUB_GW_BC_NODE_NAME[$fullIndex]}" ]]; then
            setNexthopRoute "${SUB_GW_AD_IPADDR[$fullIndex]}" "${coIndex}" "${fullIndex}" "2" "${ROUTE_LIST_2[@]}"
          fi

          # Set (5) to point to GW-A (if GW-B exists)
          if [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]]; then
            setNexthopRoute "${SUB_GW_AD_IPADDR[$coIndex]}" "${coIndex}" "${fullIndex}" "5" "${ROUTE_LIST_5[@]}"
          fi

          if [[ ! -z "${FT_CLNT_X_NODE_NAME[$coIndex]}" ]]; then
            if [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]]; then
              # Set (1) to point to GW-A (if GW-B and Clnt-X exists)
              setNexthopRoute "${SUB_GW_AD_IPADDR[$coIndex]}" "${coIndex}" "${fullIndex}" "1" "${ROUTE_LIST_1[@]}"
            fi

            echo
            echo "*** 1-a: Clnt-X to Service Endpoint:Port ***"
            echo "    Clnt-X -> GW-A -> $GWD_SVR  U  $SVR_GWD -> GW-A -> Clnt-X"
            echo

            # TEST: CLNT-X
            testClntX ${coIndex} ${fullIndex} "01-a-ClntX-A-D--D-A.txt"
          fi
        fi

        if [ "$TEST_PATH" == 0 ] || [ "$TEST_PATH" == 2 ]; then
          echo
          echo "*** 1-b: Clnt-Y to Service Endpoint:Port ***"
          echo "    Clnt-Y/GW-A -> $GWD_SVR  U  $SVR_GWD -> GW-A/Clnt-Y"
          echo

          # TEST: CLNT-Y
          testClntY ${coIndex} ${fullIndex} "01-b-ClntY-A-D--D-A.txt"


          echo
          echo "PATH 02: A-D -- D-B"
          echo "-------------------"
          if [[ "${GLOBALNET_FLAG}" == false ]] && [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]]; then
            #     (1) to point to GW-A
            #     (2) to point to GW-D
            #     (3) not set yet
            #     (4) not set yet
            # Set (5) to point to GW-A (if GW-B exists)

            # Set (5) to point to GW-A (if GW-B exists)
            setNexthopRoute "${SUB_GW_BC_IPADDR[$coIndex]}" "${coIndex}" "${fullIndex}" "5" "${ROUTE_LIST_5[@]}"

            if [[ ! -z "${FT_CLNT_X_NODE_NAME[$coIndex]}" ]]; then
              echo
              echo "*** 2-a: Clnt-X to Service Endpoint:Port ***"
              echo "    Clnt-X -> GW-A -> $GWD_SVR  U  $SVR_GWD -> GW-B -> Clnt-X"
              echo

              # TEST: CLNT-X
              testClntX ${coIndex} ${fullIndex} "02-a-ClntX-A-D--D-B.txt"
            fi

            echo
            echo "*** 2-b: Clnt-Y to Service Endpoint:Port ***"
            echo "    Clnt-Y/GW-A -> $GWD_SVR  U  $SVR_GWD -> GW-B -> GW-A/Clnt-Y"
            echo

            # TEST: CLNT-Y
            testClntY ${coIndex} ${fullIndex} "02-b-ClntY-A-D--D-B.txt"
          else
            echo "  Skipped - Only valid with Globalnet and if GW-B exists."
          fi
        fi

        if [ "$TEST_PATH" == 0 ] || [ "$TEST_PATH" == 3 ]; then
          echo
          echo "PATH 03: A-C -- C-A"
          echo "-------------------"
          if [[ ! -z "${SUB_GW_BC_NODE_NAME[$fullIndex]}" ]]; then
            #     (1) to point to GW-A
            # Set (2) to point to GW-C (if GW-C exists)
            #     (3) not set yet
            #     (4) not set yet
            #     (5) to point to GW-B

            # Set (2) to point to GW-D (if GW-C exists)
            setNexthopRoute "${SUB_GW_BC_IPADDR[$fullIndex]}" "${coIndex}" "${fullIndex}" "2" "${ROUTE_LIST_2[@]}"

            if [[ ! -z "${FT_CLNT_X_NODE_NAME[$coIndex]}" ]]; then
              echo
              echo "*** 3-a: Clnt-X to Service Endpoint:Port ***"
              echo "    Clnt-X -> GW-A -> GW-C -> $SVR_GWD  U  $SVR_GWD -> GW-C -> GW-A -> Clnt-X"
              echo

              # TEST: CLNT-X
              testClntX ${coIndex} ${fullIndex} "03-a-ClntX-A-C--C-A.txt"
            fi

            echo
            echo "*** 3-b: Clnt-Y to Service Endpoint:Port ***"
            echo "    Clnt-Y/GW-A -> GW-C -> $SVR_GWD  U  $SVR_GWD -> GW-C -> GW-A/Clnt-Y"
            echo

            # TEST: CLNT-Y
            testClntY ${coIndex} ${fullIndex} "03-b-ClntY-A-C--C-A.txt"
          else
            echo "  Skipped - Only valid if GW-C exists."
          fi
        fi

        if [ "$TEST_PATH" == 0 ] || [ "$TEST_PATH" == 4 ]; then
          echo
          echo "PATH 04: A-C -- C-B"
          echo "-------------------"
          if [[ "${GLOBALNET_FLAG}" == false ]] && [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]] && [[ ! -z "${SUB_GW_BC_NODE_NAME[$fullIndex]}" ]]; then
            #     (1) to point to GW-A
            #     (2) to point to GW-C
            #     (3) not set yet
            # Set (4) to point to GW-B (if GW-B and GW-C exists)
            #     (5) to point to GW-B

            # Set (4) to point to GW-B (if GW-B and GW-C exists)
            setNexthopRoute "${SUB_GW_BC_IPADDR[$coIndex]}" "${coIndex}" "${fullIndex}" "4" "${ROUTE_LIST_4[@]}"

            if [[ ! -z "${FT_CLNT_X_NODE_NAME[$coIndex]}" ]]; then
              echo
              echo "*** 4-a: Clnt-X to Service Endpoint:Port ***"
              echo "    Clnt-X -> GW-A -> GW-C -> $GWD_SVR  U  $SVR_GWD -> GW-C -> GW-B -> Clnt-X"
              echo

              # TEST: CLNT-X
              testClntX ${coIndex} ${fullIndex} "04-a-ClntX-A-C--C-B.txt"
            fi

            echo
            echo "*** 4-b: Clnt-Y to Service Endpoint:Port ***"
            echo "    Clnt-Y/GW-A -> GW-C -> $GWD_SVR  U  $SVR_GWD -> GW-C -> GW-B -> GW-A/Clnt-Y"
            echo

            # TEST: CLNT-Y
            testClntY ${coIndex} ${fullIndex} "04-b-ClntY-A-C--C-B.txt"
          else
            echo "  Skipped - Only valid with Globalnet and if GW-B and GW-C exists."
          fi
        fi


        if [ "$TEST_PATH" == 0 ] || [ "$TEST_PATH" == 5 ]; then
          echo
          echo "PATH 05: B-D -- D-B"
          echo "-------------------"
          if [[ ! -z "${FT_CLNT_X_NODE_NAME[$coIndex]}" ]] && [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]]; then
            # Set (1) to point to GW-B (if Clnt-X and GW-B exists)
            #     (2) to point to GW-C
            # Set (3) to point to GW-D (if GW-B and GW-C exists)
            #     (4) to point to GW-B
            # Set (5) to point to GW-B (if GW-B exists)

            # Set (1) to point to GW-B (if Clnt-X and GW-B exists)
            setNexthopRoute "${SUB_GW_BC_IPADDR[$coIndex]}" "${coIndex}" "${fullIndex}" "1" "${ROUTE_LIST_1[@]}"

            # Set (3) to point to GW-D (if GW-B and GW-C exists)
            if [[ ! -z "${SUB_GW_BC_NODE_NAME[$fullIndex]}" ]]; then
              setNexthopRoute "${SUB_GW_AD_IPADDR[$fullIndex]}" "${coIndex}" "${fullIndex}" "3" "${ROUTE_LIST_3[@]}"
            fi

            # Set (5) to point to GW-B (if GW-B exists)
            setNexthopRoute "${SUB_GW_BC_IPADDR[$coIndex]}" "${coIndex}" "${fullIndex}" "5" "${ROUTE_LIST_5[@]}"

            echo
            echo "*** 5-a: Clnt-X to Service Endpoint:Port ***"
            echo "    Clnt-X -> GW-B -> $GWD_SVR  U  $SVR_GWD -> GW-B -> Clnt-X"
            echo

            # TEST: CLNT-X
            testClntX ${coIndex} ${fullIndex} "05-a-ClntX-B-D--D-B.txt"
          else
            echo "  Skipped - Only valid if Clnt-X and GW-B exists."
          fi
        fi

        if [ "$TEST_PATH" == 0 ] || [ "$TEST_PATH" == 6 ]; then
          echo
          echo "PATH 06: B-D -- D-A"
          echo "-------------------"
          if [[ "${GLOBALNET_FLAG}" == false ]] && [[ ! -z "${FT_CLNT_X_NODE_NAME[$coIndex]}" ]] && [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]]; then
            #     (1) to point to GW-B
            #     (2) to point to GW-C
            #     (3) to point to GW-D
            #     (4) to point to GW-B
            # Set (5) to point to GW-A (if GW-B exists)

            # Set (5) to point to GW-A (if GW-B exists)
            setNexthopRoute "${SUB_GW_AD_IPADDR[$coIndex]}" "${coIndex}" "${fullIndex}" "5" "${ROUTE_LIST_5[@]}"

            echo
            echo "*** 6-a: Clnt-X to Service Endpoint:Port ***"
            echo "    Clnt-X -> GW-B -> $GWD_SVR  U  $SVR_GWD -> GW-A -> Clnt-X"
            echo

            # TEST: CLNT-X
            testClntX ${coIndex} ${fullIndex} "06-a-ClntX-B-D--D-A.txt"
          else
            echo "  Skipped - Only valid with Globalnet and if Clnt-X and GW-B exists."
          fi
        fi

        if [ "$TEST_PATH" == 0 ] || [ "$TEST_PATH" == 7 ]; then
          echo
          echo "PATH 07: B-C -- C-B"
          echo "-------------------"
          if [[ ! -z "${FT_CLNT_X_NODE_NAME[$coIndex]}" ]] && [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]] && [[ ! -z "${SUB_GW_BC_NODE_NAME[$fullIndex]}" ]]; then
            #     (1) to point to GW-B
            #     (2) to point to GW-C
            # Set (3) to point to GW-C (if GW-B and GW-C exists)
            # Set (4) to point to GW-B (if GW-B and GW-C exists)
            #     (5) to point to GW-A

            # Set (3) to point to GW-C (if GW-B and GW-C exists)
            setNexthopRoute "${SUB_GW_BC_IPADDR[$fullIndex]}" "${coIndex}" "${fullIndex}" "3" "${ROUTE_LIST_3[@]}"

            # Set (4) to point to GW-B (if GW-B and GW-C exists)
            setNexthopRoute "${SUB_GW_BC_IPADDR[$coIndex]}" "${coIndex}" "${fullIndex}" "4" "${ROUTE_LIST_4[@]}"

            echo
            echo "*** 7-a: Clnt-X to Service Endpoint:Port ***"
            echo "    Clnt-X -> GW-B -> GW-C -> $GWD_SVR  U  $SVR_GWD -> GW-C -> GW-B -> Clnt-X"
            echo

            # TEST: CLNT-X
            testClntX ${coIndex} ${fullIndex} "07-a-ClntX-B-C--C-B.txt"
          else
            echo "  Skipped - Only valid if Clnt-X and GW-B and GW-C exists."
          fi
        fi

        if [ "$TEST_PATH" == 0 ] || [ "$TEST_PATH" == 8 ]; then
          echo
          echo "PATH 08: B-C -- C-A"
          echo "-------------------"
          if [[ "${GLOBALNET_FLAG}" == false ]] && [[ ! -z "${FT_CLNT_X_NODE_NAME[$coIndex]}" ]] && [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]] && [[ ! -z "${SUB_GW_BC_NODE_NAME[$fullIndex]}" ]]; then
            #     (1) to point to GW-B
            #     (2) to point to GW-C
            #     (3) to point to GW-C
            # Set (4) to point to GW-A (if GW-B and GW-C exists)
            #     (5) to point to GW-A

            # Set (4) to point to GW-B (if GW-B and GW-C exists)
            setNexthopRoute "${SUB_GW_AD_IPADDR[$coIndex]}" "${coIndex}" "${fullIndex}" "4" "${ROUTE_LIST_4[@]}"

            echo
            echo "*** 8-a: Clnt-X to Service Endpoint:Port ***"
            echo "    Clnt-X -> GW-B -> GW-C -> $GWD_SVR  U  $SVR_GWD -> GW-C -> GW-A -> Clnt-X"
            echo

            # TEST: CLNT-X
            testClntX ${coIndex} ${fullIndex} "08-a-ClntX-B-C--C-A.txt"
          else
            echo "  Skipped - Only valid with Globalnet and if Clnt-X and GW-B and GW-C exists."
          fi
        fi

        #
        # Restore all Routes
        #
        echo
        if [[ ! -z "${SUB_GW_BC_NODE_NAME[$fullIndex]}" ]]; then
          # Restore (2) if GW-C exists
          restoreNexthopRoute "${coIndex}" "${fullIndex}" "2" "${ROUTE_LIST_2[@]}"
        fi

        if [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]]; then
          # Restore (5) if GW-B exists
          restoreNexthopRoute "${coIndex}" "${fullIndex}" "5" "${ROUTE_LIST_5[@]}"

          if [[ ! -z "${FT_CLNT_X_NODE_NAME[$coIndex]}" ]]; then
            # Restore (1) if GW-B and Clnt-X exists
            restoreNexthopRoute "${coIndex}" "${fullIndex}" "1" "${ROUTE_LIST_1[@]}"
          fi

          if [[ ! -z "${SUB_GW_BC_NODE_NAME[$coIndex]}" ]]; then
            # Restore (3) if GW-B and GW-C exists
            restoreNexthopRoute "${coIndex}" "${fullIndex}" "3" "${ROUTE_LIST_3[@]}"

            # Restore (4) if GW-B and GW-C exists
            restoreNexthopRoute "${coIndex}" "${fullIndex}" "4" "${ROUTE_LIST_4[@]}"
          fi
        fi
      fi
    done
  fi
done

# Restore context to original.
echo
kubectl config use-context ${ORIG_CONTEXT}
