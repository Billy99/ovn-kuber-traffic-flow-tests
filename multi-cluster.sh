#!/bin/bash

SVC_LIST=(
  ${HTTP_CLUSTERIP_POD_SVC_NAME}
  ${HTTP_CLUSTERIP_HOST_SVC_NAME}
  ${IPERF_CLUSTERIP_POD_SVC_NAME}
  ${IPERF_CLUSTERIP_HOST_SVC_NAME}
)


manage_multi_cluster() {
  if [ "$FT_EXPORT_SVC" == true ]; then
    # subctl command exists, use it to export each service.
    echo "Exporting Services:"

    # See if subctl is install
    subctl version  &>/dev/null

    if [ $? == 0 ]; then
      for i in "${!SVC_LIST[@]}"
      do
        echo "subctl export service --namespace $FT_NAMESPACE ${SVC_LIST[$i]}"
        TMP_OUTPUT=`subctl export service --namespace $FT_NAMESPACE ${SVC_LIST[$i]}`
        echo "${TMP_OUTPUT}"

        # Dump command output
        if [ $? != 0 ] || [ "$VERBOSE" == true ]; then
          echo "${TMP_OUTPUT}"
        fi
      done
    else
      echo "\"subctl\" not installed!"
    fi
  else
    echo "Exporting Services not enabled."
  fi
}
