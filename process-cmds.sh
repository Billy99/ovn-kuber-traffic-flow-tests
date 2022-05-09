#!/bin/bash


#
# Functions
#

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
  #
  #   Debug:
  #     MY_CLUSTER
  #     TEST_CLIENT_NODE
  #     TEST_SERVER_CLUSTER
  #     TEST_SERVER_NODE
  # If not used, VARIABLE should be blank for 'if [ -z "${VARIABLE}" ]' test.

  echo "${MY_CLUSTER}:${TEST_CLIENT_NODE} -> ${TEST_SERVER_CLUSTER}:${TEST_SERVER_NODE}"

  if [ -z "${TEST_CLIENT_POD}" ]; then
    # From External (no 'kubectl exec')
    echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}${SERVER_PATH}\""
    TMP_OUTPUT=`$CURL_CMD "http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}${SERVER_PATH}"`
  elif [ -z "${TEST_SERVER_HTTP_DST_PORT}" ]; then
    # No Port, so leave off Port from command
    echo "kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}/\""
    TMP_OUTPUT=`kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD "http://${TEST_SERVER_HTTP_DST}/"`
  else
    # Default command

    # If Kubebernetes API, include --cacert and -H TOKEN
    if [ "${TEST_SERVER_RSP}" == "${KUBEAPI_SERVER_STRING}" ]; then
      LCL_SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount

      echo "LCL_TOKEN=kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- cat ${LCL_SERVICEACCOUNT}/token"
      LCL_TOKEN=`kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- cat ${LCL_SERVICEACCOUNT}/token`

      echo "kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD --cacert ${LCL_SERVICEACCOUNT}/ca.crt  -H \"Authorization: Bearer LCL_TOKEN\" -X GET \"https://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/api\""
      TMP_OUTPUT=`kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD --cacert ${LCL_SERVICEACCOUNT}/ca.crt  -H "Authorization: Bearer ${LCL_TOKEN}" -X GET "https://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/api"`
    else
      #kubectl config get-contexts
      echo "kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}${SERVER_PATH}\""
      TMP_OUTPUT=`kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD "http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}${SERVER_PATH}"`
    fi
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
  TASKSET_CMD=""
  if [[ ! -z "${FT_CLIENT_CPU_MASK}" ]]; then
    TASKSET_CMD="taskset ${FT_CLIENT_CPU_MASK} "
  fi

  echo "${MY_CLUSTER}:${TEST_CLIENT_NODE} -> ${TEST_SERVER_CLUSTER}:${TEST_SERVER_NODE}"

  IPERF_FILENAME="${IPERF_LOGS_DIR}/${TEST_FILENAME}"

  echo "kubectl exec -it -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- ${TASKSET_CMD}${IPERF_CMD} -c ${TEST_SERVER_IPERF_DST} -p ${TEST_SERVER_IPERF_DST_PORT} -t ${IPERF_TIME}"
  kubectl exec -it -n "${FT_NAMESPACE}" "$TEST_CLIENT_POD" -- /bin/sh -c "${TASKSET_CMD} ${IPERF_CMD} -c ${TEST_SERVER_IPERF_DST} -p ${TEST_SERVER_IPERF_DST_PORT} -t ${IPERF_TIME}"  > "${IPERF_FILENAME}"

  # Dump command output
  if [ "$VERBOSE" == true ]; then
    echo "Full Output (from ${IPERF_FILENAME}):"
    cat ${IPERF_FILENAME}
  else
    echo "Summary (see ${IPERF_FILENAME} for full detail):"
    cat ${IPERF_FILENAME} | grep -B 1 -A 1 "sender"
  fi

  # Print SUCCESS or FAILURE
  cat ${IPERF_FILENAME} | grep -cq "sender" && echo -e "${GREEN}SUCCESS${NC}\r\n" || echo -e "${RED}FAILED${NC}\r\n"
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
  TRACE_FILENAME="${OVN_TRACE_LOGS_DIR}/${TEST_FILENAME}"

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
