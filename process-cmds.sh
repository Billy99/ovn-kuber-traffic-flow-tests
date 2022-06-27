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

  echo "=== CURL ==="
  echo "${MY_CLUSTER}:${TEST_CLIENT_NODE} -> ${TEST_SERVER_CLUSTER}:${TEST_SERVER_NODE}"

  if [ -z "${TEST_CLIENT_POD}" ]; then
    # From External (no 'kubectl exec')
    echo "$CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}${SERVER_PATH}\""
    TMP_OUTPUT=`$CURL_CMD "http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}${SERVER_PATH}"`
  elif [ -z "${TEST_SERVER_HTTP_DST_PORT}" ]; then
    # No Port, so leave off Port from command
    echo "kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}/\""
    TMP_OUTPUT=`kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD "http://${TEST_SERVER_HTTP_DST}/"`
  else
    # Default command

    # If Kubebernetes API, include --cacert and -H TOKEN
    if [ "${TEST_SERVER_RSP}" == "${KUBEAPI_SERVER_STRING}" ]; then
      LCL_SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount

      echo "LCL_TOKEN=kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- cat ${LCL_SERVICEACCOUNT}/token"
      LCL_TOKEN=`kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- cat ${LCL_SERVICEACCOUNT}/token`

      echo "kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD --cacert ${LCL_SERVICEACCOUNT}/ca.crt  -H \"Authorization: Bearer LCL_TOKEN\" -X GET \"https://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/api\""
      TMP_OUTPUT=`kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD --cacert ${LCL_SERVICEACCOUNT}/ca.crt  -H "Authorization: Bearer ${LCL_TOKEN}" -X GET "https://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}/api"`
    else
      #kubectl config get-contexts
      echo "kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD \"http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}${SERVER_PATH}\""
      TMP_OUTPUT=`kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- $CURL_CMD "http://${TEST_SERVER_HTTP_DST}:${TEST_SERVER_HTTP_DST_PORT}${SERVER_PATH}"`
    fi
  fi

  # Dump command output
  if [ "$VERBOSE" == true ]; then
    echo "${TMP_OUTPUT}"
  fi

  # Print SUCCESS or FAILURE
  echo "${TMP_OUTPUT}" | grep -cq "${TEST_SERVER_RSP}" && echo -e "\r\n${GREEN}SUCCESS${NC}\r\n" || echo -e "\r\n${RED}FAILED${NC}\r\n"
}

process-iperf() {
  # The following VARIABLES are used by this function:
  #     TEST_CLIENT_POD
  #     FORWARD_TEST_FILENAME
  #     REVERSE_TEST_FILENAME
  #     TEST_SERVER_IPERF_DST
  #     TEST_SERVER_IPERF_DST_PORT
  TASKSET_CMD=""
  if [[ ! -z "${FT_CLIENT_CPU_MASK}" ]]; then
    TASKSET_CMD="taskset ${FT_CLIENT_CPU_MASK} "
  fi

  IPERF_FILENAME_FORWARD_TEST="${IPERF_LOGS_DIR}/${FORWARD_TEST_FILENAME}"
  IPERF_FILENAME_REVERSE_TEST="${IPERF_LOGS_DIR}/${REVERSE_TEST_FILENAME}"

  echo "=== IPERF ==="
  echo "== ${MY_CLUSTER}:${TEST_CLIENT_NODE} -> ${TEST_SERVER_CLUSTER}:${TEST_SERVER_NODE} =="
  echo "kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- ${TASKSET_CMD} ${IPERF_CMD} ${IPERF_FORWARD_TEST_OPT} -c ${TEST_SERVER_IPERF_DST} -p ${TEST_SERVER_IPERF_DST_PORT} -t ${IPERF_TIME}"
  kubectl exec -n "${FT_NAMESPACE}" "$TEST_CLIENT_POD" -- /bin/sh -c "${TASKSET_CMD} ${IPERF_CMD} ${IPERF_FORWARD_TEST_OPT} -c ${TEST_SERVER_IPERF_DST} -p ${TEST_SERVER_IPERF_DST_PORT} -t ${IPERF_TIME}"  > "${IPERF_FILENAME_FORWARD_TEST}"

  # Dump command output
  if [ "$VERBOSE" == true ]; then
    echo "Full Output (from ${IPERF_FILENAME_FORWARD_TEST}):"
    cat ${IPERF_FILENAME_FORWARD_TEST}
  else
    echo "Summary (see ${IPERF_FILENAME_FORWARD_TEST} for full detail):"
    cat ${IPERF_FILENAME_FORWARD_TEST} | grep -B 1 -A 1 "sender"
  fi

  # Print SUCCESS or FAILURE
  cat ${IPERF_FILENAME_FORWARD_TEST} | grep -cq "sender" && echo -e "\r\n${GREEN}SUCCESS${NC}\r\n" || echo -e "\r\n${RED}FAILED${NC}\r\n"

  echo "== ${MY_CLUSTER}:${TEST_CLIENT_NODE} -> ${TEST_SERVER_CLUSTER}:${TEST_SERVER_NODE} (Reverse) =="
  echo "kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- ${TASKSET_CMD} ${IPERF_CMD} ${IPERF_REVERSE_TEST_OPT} -c ${TEST_SERVER_IPERF_DST} -p ${TEST_SERVER_IPERF_DST_PORT} -t ${IPERF_TIME}"
  kubectl exec -n "${FT_NAMESPACE}" "$TEST_CLIENT_POD" -- /bin/sh -c "${TASKSET_CMD} ${IPERF_CMD} ${IPERF_REVERSE_TEST_OPT} -c ${TEST_SERVER_IPERF_DST} -p ${TEST_SERVER_IPERF_DST_PORT} -t ${IPERF_TIME}"  > "${IPERF_FILENAME_REVERSE_TEST}"

  # Dump command output
  if [ "$VERBOSE" == true ]; then
    echo "Full Output (from ${IPERF_FILENAME_REVERSE_TEST}):"
    cat ${IPERF_FILENAME_REVERSE_TEST}
  else
    echo "Summary (see ${IPERF_FILENAME_REVERSE_TEST} for full detail):"
    cat ${IPERF_FILENAME_REVERSE_TEST} | grep -B 1 -A 1 "sender"
  fi

  # Print SUCCESS or FAILURE
  cat ${IPERF_FILENAME_REVERSE_TEST} | grep -cq "sender" && echo -e "\r\n${GREEN}SUCCESS${NC}\r\n" || echo -e "\r\n${RED}FAILED${NC}\r\n"
}

process-vf-rep-stats() {
  # The following VARIABLES are used by this function:
  #     TEST_CLIENT_POD
  #     HWOL_VALIDATION_FILENAME
  #     TEST_SERVER_IPERF_DST
  #     TEST_SERVER_IPERF_DST_PORT
  #     IPERF_OPT

  # This is a threshold to catch whether hardware offload is working
  THRESHOLD_PKT_COUNT=100

  # Need sufficient time for validating hardware offload
  # TODO: How can we use IPERF_TIME
  IPERF_RUNTIME=40
  FLOW_LEARNING_TIME=5
  TCPDUMP_RUNTIME=25

  IPERF_FILENAME="${HWOL_VALIDATION_FILENAME}.iperf"
  TCPDUMP_FILENAME="${HWOL_VALIDATION_FILENAME}.tcpdump"

  TASKSET_CMD=""
  if [[ ! -z "${FT_CLIENT_CPU_MASK}" ]]; then
    TASKSET_CMD="taskset ${FT_CLIENT_CPU_MASK} "
  fi

  # Start IPERF in background
  echo "kubectl exec -n ${FT_NAMESPACE} ${TEST_CLIENT_POD} -- ${TASKSET_CMD} ${IPERF_CMD} ${IPERF_OPT} -c ${TEST_SERVER_IPERF_DST} -p ${TEST_SERVER_IPERF_DST_PORT} -t ${IPERF_RUNTIME}"
  kubectl exec -n "${FT_NAMESPACE}" "$TEST_CLIENT_POD" -- /bin/sh -c "${TASKSET_CMD} ${IPERF_CMD} ${IPERF_OPT} -c ${TEST_SERVER_IPERF_DST} -p ${TEST_SERVER_IPERF_DST_PORT} -t ${IPERF_RUNTIME}" > "${IPERF_FILENAME}" &
  IPERF_PID=$!

  # Wait to learn flows and hardware offload
  sleep "${FLOW_LEARNING_TIME}"

  # Record ethtool stats
  echo "kubectl exec -n \"${FT_NAMESPACE}\" \"${TEST_TOOLS_POD}\" -- /bin/sh -c \"ethtool -S ${TEST_VF_REP} | sed -n 's/^\s\+//p'\""
  ethtoolstart=$(kubectl exec -n "${FT_NAMESPACE}" "${TEST_TOOLS_POD}" -- /bin/sh -c "ethtool -S ${TEST_VF_REP} | sed -n 's/^\s\+//p'")
  echo "${ethtoolstart}" >> "${HWOL_VALIDATION_FILENAME}"

  # Record RX/TX packet counts
  rxpktstart=$(echo "$ethtoolstart" | sed -n "s/^rx_packets:\s\+//p" | sed "s/[^0-9]//g")
  txpktstart=$(echo "$ethtoolstart" | sed -n "s/^tx_packets:\s\+//p" | sed "s/[^0-9]//g")

  # Start tcpdump
  echo "kubectl exec -n \"${FT_NAMESPACE}\" \"${TEST_TOOLS_POD}\" -- /bin/sh -c \"timeout --preserve-status ${TCPDUMP_RUNTIME} tcpdump -v -i ${TEST_VF_REP} -n not arp\""
  kubectl exec -n "${FT_NAMESPACE}" "${TEST_TOOLS_POD}" -- /bin/sh -c "timeout --preserve-status ${TCPDUMP_RUNTIME} tcpdump -v -i ${TEST_VF_REP} -n not arp" > "${TCPDUMP_FILENAME}" 2>&1
  cat "${TCPDUMP_FILENAME}" >> "${HWOL_VALIDATION_FILENAME}"

  # Record ethtool stats
  # This records the ethtool stats before Iperf finishes because at the end of Iperf
  # the TCP connection will close. There are packets when the TCP connection closes
  # that won't be hardware offloaded.
  [ "$FT_DEBUG" == true ] &&  echo "kubectl exec -n \"${FT_NAMESPACE}\" \"${TEST_TOOLS_POD}\" -- /bin/sh -c \"ethtool -S ${TEST_VF_REP} | sed -n 's/^\s\+//p'\""
  ethtoolend=$(kubectl exec -n "${FT_NAMESPACE}" "${TEST_TOOLS_POD}" -- /bin/sh -c "ethtool -S ${TEST_VF_REP} | sed -n 's/^\s\+//p'")
  echo "${ethtoolend}" >> "${HWOL_VALIDATION_FILENAME}"

  rxpktend=$(echo "$ethtoolend" | sed -n "s/^rx_packets:\s\+//p" | sed "s/[^0-9]//g")
  txpktend=$(echo "$ethtoolend" | sed -n "s/^tx_packets:\s\+//p" | sed "s/[^0-9]//g")

  rxcount=$(( rxpktend - rxpktstart ))
  txcount=$(( txpktend - txpktstart ))

  echo "Summary (see ${HWOL_VALIDATION_FILENAME} for full detail):"
  echo "Summary Ethtool results for ${TEST_CLIENT_CLIENT_VF_REP}:"
  echo "RX Packets: ${rxpktend} - ${rxpktstart} = ${rxcount}"
  echo "TX Packets: ${txpktend} - ${txpktstart} = ${txcount}"

  # Wait for Iperf to finish
  wait $IPERF_PID

  # Concatenate the background Iperf results into the same file
  cat "${IPERF_FILENAME}" >> "${HWOL_VALIDATION_FILENAME}"

  # Dump command output
  if [ "$VERBOSE" == true ]; then
    echo "Full Tcpdump Output:"
    cat ${TCPDUMP_FILENAME}
    echo "Full Iperf Output:"
    cat ${IPERF_FILENAME}
  else
    echo "Summary Tcpdump Output:"
    tail ${TCPDUMP_FILENAME}
    echo "Summary Iperf Output:"
    cat ${IPERF_FILENAME} | grep -B 1 -A 1 "sender"
  fi

  cat ${IPERF_FILENAME} | grep -cq "sender" && retVal=0 || retVal=1

  if (( rxcount > THRESHOLD_PKT_COUNT )) || (( txcount > THRESHOLD_PKT_COUNT )); then
    retVal=1
  fi

  # Cleanup temporary files
  rm "${IPERF_FILENAME}"
  rm "${TCPDUMP_FILENAME}"

  return $retVal
}

process-hw-offload-validation() {
  # The following VARIABLES are used by this function:
  #     TEST_CLIENT_NODE
  #     TEST_SERVER_NODE
  #     TEST_CLIENT_POD
  #     FORWARD_TEST_FILENAME
  #     REVERSE_TEST_FILENAME
  #     TEST_SERVER_IPERF_DST
  #     TEST_SERVER_IPERF_DST_PORT
  #     IPERF_FORWARD_TEST_OPT
  #     IPERF_REVERSE_TEST_OPT

  [ "$FT_DEBUG" == true ] && echo "kubectl get pods -n ${FT_NAMESPACE} --selector=name=${TOOLS_POD_NAME} -o wide"
  TMP_OUTPUT=$(kubectl get pods -n ${FT_NAMESPACE} --selector=name=${TOOLS_POD_NAME} -o wide)
  TOOLS_CLIENT_POD=$(echo "${TMP_OUTPUT}" | grep -w "${TEST_CLIENT_NODE}" | awk -F' ' '{print $1}')
  TOOLS_SERVER_POD=$(echo "${TMP_OUTPUT}" | grep -w "${TEST_SERVER_NODE}" | awk -F' ' '{print $1}')

  [ "$FT_DEBUG" == true ] && echo "kubectl exec -n \"${FT_NAMESPACE}\" \"${TOOLS_SERVER_POD}\" -- /bin/sh -c \"chroot /host /bin/bash -c \"crictl ps -a --name=${IPERF_SERVER_POD_NAME} -o json | jq -r \".containers[].podSandboxId\"\"\""
  TEST_SERVER_IPERF_SERVER_PODID=`kubectl exec -n "${FT_NAMESPACE}" "${TOOLS_SERVER_POD}" -- /bin/sh -c "chroot /host /bin/bash -c \"crictl ps -a --name=${IPERF_SERVER_POD_NAME} -o json | jq -r \".containers[].podSandboxId\"\""`
  [ "$FT_DEBUG" == true ] && echo "kubectl exec -n \"${FT_NAMESPACE}\" \"${TOOLS_SERVER_POD}\" -- /bin/sh -c \"chroot /host /bin/bash -c \"crictl ps -a --name=${CLIENT_POD_NAME_PREFIX} -o json | jq -r \".containers[].podSandboxId\"\"\""
  TEST_SERVER_CLIENT_PODID=`kubectl exec -n "${FT_NAMESPACE}" "${TOOLS_SERVER_POD}" -- /bin/sh -c "chroot /host /bin/bash -c \"crictl ps -a --name=${CLIENT_POD_NAME_PREFIX} -o json | jq -r \".containers[].podSandboxId\"\""`
  [ "$FT_DEBUG" == true ] && echo "kubectl exec -n \"${FT_NAMESPACE}\" \"${TOOLS_CLIENT_POD}\" -- /bin/sh -c \"chroot /host /bin/bash -c \"crictl ps -a --name=${CLIENT_POD_NAME_PREFIX} -o json | jq -r \".containers[].podSandboxId\"\"\""
  TEST_CLIENT_CLIENT_PODID=`kubectl exec -n "${FT_NAMESPACE}" "${TOOLS_CLIENT_POD}" -- /bin/sh -c "chroot /host /bin/bash -c \"crictl ps -a --name=${CLIENT_POD_NAME_PREFIX} -o json | jq -r \".containers[].podSandboxId\"\""`

  TEST_SERVER_IPERF_SERVER_VF_REP=${TEST_SERVER_IPERF_SERVER_PODID::15}
  TEST_SERVER_CLIENT_VF_REP=${TEST_SERVER_CLIENT_PODID::15}
  TEST_CLIENT_CLIENT_VF_REP=${TEST_CLIENT_CLIENT_PODID::15}

  if [ "$FT_DEBUG" == true ]; then
    echo "Variables Used For Hardware Offload Validation:"
    echo "================================================"
    echo "  TOOLS_CLIENT_POD=${TOOLS_CLIENT_POD}"
    echo "  TOOLS_SERVER_POD=${TOOLS_SERVER_POD}"
    echo "  TEST_SERVER_IPERF_SERVER_PODID=${TEST_SERVER_IPERF_SERVER_PODID}"
    echo "  TEST_SERVER_CLIENT_PODID=${TEST_SERVER_CLIENT_PODID}"
    echo "  TEST_CLIENT_CLIENT_PODID=${TEST_CLIENT_CLIENT_PODID}"
    echo "  TEST_SERVER_IPERF_SERVER_VF_REP=${TEST_SERVER_IPERF_SERVER_VF_REP}"
    echo "  TEST_SERVER_CLIENT_VF_REP=${TEST_SERVER_CLIENT_VF_REP}"
    echo "  TEST_CLIENT_CLIENT_VF_REP=${TEST_CLIENT_CLIENT_VF_REP}"
    echo "================================================"
  fi

  IPERF_OPT=$IPERF_FORWARD_TEST_OPT
  HWOL_VALIDATION_FILENAME="${HW_OFFLOAD_LOGS_DIR}/${FORWARD_TEST_FILENAME}"
  echo "=== HWOL ==="
  echo "== ${MY_CLUSTER}:${TEST_CLIENT_NODE} -> ${TEST_SERVER_CLUSTER}:${TEST_SERVER_NODE} =="
  echo -e "= Client Pod on Client Host VF Representor Results =" > "${HWOL_VALIDATION_FILENAME}"
  echo -e "= Client Pod on Client Host VF Representor Results ="
  TEST_TOOLS_POD=$TOOLS_CLIENT_POD
  TEST_VF_REP=$TEST_CLIENT_CLIENT_VF_REP
  process-vf-rep-stats
  vfRes1=$?

  echo -e "\r\n= Client Pod on Server Host VF Representor Results =" >> "${HWOL_VALIDATION_FILENAME}"
  echo -e "\r\n= Client Pod on Server Host VF Representor Results ="
  TEST_TOOLS_POD=$TOOLS_SERVER_POD
  TEST_VF_REP=$TEST_SERVER_CLIENT_VF_REP
  process-vf-rep-stats
  vfRes2=$?

  echo -e "\r\n= Server Pod on Server Host VF Representor Results =" >> "${HWOL_VALIDATION_FILENAME}"
  echo -e "\r\n= Server Pod on Server Host VF Representor Results ="
  TEST_TOOLS_POD=$TOOLS_SERVER_POD
  TEST_VF_REP=$TEST_SERVER_IPERF_SERVER_VF_REP
  process-vf-rep-stats
  vfRes3=$?

  if [ $vfRes1 -ne 0 ] || [ $vfRes2 -ne 0 ] || [ $vfRes3 -ne 0 ]; then
    echo -e "\r\n${RED}FAILED${NC}\r\n"
  else
    echo -e "\r\n${GREEN}SUCCESS${NC}\r\n"
  fi

  IPERF_OPT=$IPERF_REVERSE_TEST_OPT
  HWOL_VALIDATION_FILENAME="${HW_OFFLOAD_LOGS_DIR}/${REVERSE_TEST_FILENAME}"
  echo "== ${MY_CLUSTER}:${TEST_CLIENT_NODE} -> ${TEST_SERVER_CLUSTER}:${TEST_SERVER_NODE} (Reverse) =="
  echo -e "= Client Pod on Client Host VF Representor Results (Reverse) =" > "${HWOL_VALIDATION_FILENAME}"
  echo -e "= Client Pod on Client Host VF Representor Results (Reverse) ="
  TEST_TOOLS_POD=$TOOLS_CLIENT_POD
  TEST_VF_REP=$TEST_CLIENT_CLIENT_VF_REP
  process-vf-rep-stats
  vfRes4=$?

  echo -e "\r\n= Client Pod on Server Host VF Representor Results (Reverse) =" >> "${HWOL_VALIDATION_FILENAME}"
  echo -e "\r\n= Client Pod on Server Host VF Representor Results (Reverse) ="
  TEST_TOOLS_POD=$TOOLS_SERVER_POD
  TEST_VF_REP=$TEST_SERVER_CLIENT_VF_REP
  process-vf-rep-stats
  vfRes5=$?

  echo -e "\r\n= Server Pod on Server Host VF Representor Results (Reverse) =" >> "${HWOL_VALIDATION_FILENAME}"
  echo -e "\r\n= Server Pod on Server Host VF Representor Results (Reverse) ="
  TEST_TOOLS_POD=$TOOLS_SERVER_POD
  TEST_VF_REP=$TEST_SERVER_IPERF_SERVER_VF_REP
  process-vf-rep-stats
  vfRes6=$?

  if [ $vfRes4 -ne 0 ] || [ $vfRes5 -ne 0 ] || [ $vfRes6 -ne 0 ]; then
    echo -e "\r\n${RED}FAILED${NC}\r\n"
  else
    echo -e "\r\n${GREEN}SUCCESS${NC}\r\n"
  fi
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
