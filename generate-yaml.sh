#!/bin/bash

shopt -s expand_aliases

install_j2_renderer() {
  # Determine if `j2 renderer` is installed
  j2 -v &>/dev/null

  if [ $? != 0 ]; then
    # Determine if `pip` is installed
    pip -V &>/dev/null
    if [ $? == 0 ]; then
      pip install wheel --user
      pip freeze | grep j2cli || pip install j2cli[yaml] --user
      export PATH=~/.local/bin:$PATH
    else
      # Determine if `pip3` is installed
      pip3 -V &>/dev/null
      if [ $? != 0 ]; then
        dnf install python3-pip python3-wheel
        if [ $? != 0 ]; then
          echo
          echo "Install \`j2\` or install \`pip\` or \`pip3\` so script can install \`j2\`. Exiting ..."
          echo
          exit 1
        fi
      fi

      pip3 install wheel --user
      pip3 freeze | grep j2cli || pip3 install j2cli[yaml] --user
      export PATH=~/.local/bin:$PATH
    fi
  fi
}

generate_yamls() {

  #
  # Namespace
  #
  namespace=${FT_NAMESPACE} \
  j2 "./manifests/namespace.yaml.j2" -o "./manifests/yamls/namespace.yaml"

  #
  # Client Pods
  #

  # client-daemonSet-host.yaml
  namespace=${FT_NAMESPACE} \
  test_image=${TEST_IMAGE} \
  j2 "./manifests/client-daemonSet-host.yaml.j2" -o "./manifests/yamls/client-daemonSet-host.yaml"

  # client-daemonSet-sriov.yaml
  namespace=${FT_NAMESPACE} \
  net_attach_def_name=${NET_ATTACH_DEF_NAME} \
  sriov_resource_name=${SRIOV_RESOURCE_NAME} \
  test_image=${TEST_IMAGE} \
  j2 "./manifests/client-daemonSet-sriov.yaml.j2" -o "./manifests/yamls/client-daemonSet-sriov.yaml"

  # client-daemonSet.yaml
  namespace=${FT_NAMESPACE} \
  test_image=${TEST_IMAGE} \
  j2 "./manifests/client-daemonSet.yaml.j2" -o "./manifests/yamls/client-daemonSet.yaml"

  #
  # Tools Pods
  #

  # tool-daemonSet.yaml
  namespace=${FT_NAMESPACE} \
  j2 "./manifests/tools-daemonSet.yaml.j2" -o "./manifests/yamls/tools-daemonSet.yaml"

  #
  # http Server Pods
  #

  # http-server-pod-v4-host.yaml
  namespace=${FT_NAMESPACE} \
  test_image=${TEST_IMAGE} \
  server_path=${SERVER_PATH} \
  http_clusterip_host_svc_port=${HTTP_CLUSTERIP_HOST_SVC_PORT} \
  j2 "./manifests/http-server-pod-v4-host.yaml.j2" -o "./manifests/yamls/http-server-pod-v4-host.yaml"

  # http-server-pod-v4-sriov
  namespace=${FT_NAMESPACE} \
  test_image=${TEST_IMAGE} \
  server_path=${SERVER_PATH} \
  net_attach_def_name=${NET_ATTACH_DEF_NAME} \
  sriov_resource_name=${SRIOV_RESOURCE_NAME} \
  http_clusterip_pod_svc_port=${HTTP_CLUSTERIP_POD_SVC_PORT} \
  j2 "./manifests/http-server-pod-v4-sriov.yaml.j2" -o "./manifests/yamls/http-server-pod-v4-sriov.yaml"

  # http-server-pod-v4.yaml
  namespace=${FT_NAMESPACE} \
  test_image=${TEST_IMAGE} \
  server_path=${SERVER_PATH} \
  http_clusterip_pod_svc_port=${HTTP_CLUSTERIP_POD_SVC_PORT} \
  j2 "./manifests/http-server-pod-v4.yaml.j2" -o "./manifests/yamls/http-server-pod-v4.yaml"

  #
  # iperf Server Pods
  #

  # iperf-server-pod-v4-host.yaml
  namespace=${FT_NAMESPACE} \
  test_image=${TEST_IMAGE} \
  iperf_clusterip_host_svc_port=${IPERF_CLUSTERIP_HOST_SVC_PORT} \
  j2 "./manifests/iperf-server-pod-v4-host.yaml.j2" -o "./manifests/yamls/iperf-server-pod-v4-host.yaml"

  # iperf-server-pod-v4-sriov.yaml
  namespace=${FT_NAMESPACE} \
  net_attach_def_name=${NET_ATTACH_DEF_NAME} \
  sriov_resource_name=${SRIOV_RESOURCE_NAME} \
  test_image=${TEST_IMAGE} \
  iperf_clusterip_pod_svc_port=${IPERF_CLUSTERIP_POD_SVC_PORT} \
  j2 "./manifests/iperf-server-pod-v4-sriov.yaml.j2" -o "./manifests/yamls/iperf-server-pod-v4-sriov.yaml"

  # iperf-server-pod-v4.yaml
  namespace=${FT_NAMESPACE} \
  test_image=${TEST_IMAGE} \
  iperf_clusterip_pod_svc_port=${IPERF_CLUSTERIP_POD_SVC_PORT} \
  j2 "./manifests/iperf-server-pod-v4.yaml.j2" -o "./manifests/yamls/iperf-server-pod-v4.yaml"


  #
  # Network-Attachment-Definitions
  #

  # netAttachDef-sriov.yaml
  namespace=${FT_NAMESPACE} \
  net_attach_def_name=${NET_ATTACH_DEF_NAME} \
  sriov_resource_name=${SRIOV_RESOURCE_NAME} \
  iperf_clusterip_host_svc_port=${IPERF_CLUSTERIP_HOST_SVC_PORT} \
  j2 "./manifests/netAttachDef-sriov.yaml.j2" -o "./manifests/yamls/netAttachDef-sriov.yaml"


  #
  # Services
  #

  # svc-clusterIP.yaml
  namespace=${FT_NAMESPACE} \
  http_clusterip_host_svc_port=${HTTP_CLUSTERIP_HOST_SVC_PORT} \
  iperf_clusterip_host_svc_port=${IPERF_CLUSTERIP_HOST_SVC_PORT} \
  j2 "./manifests/svc-clusterIP-host.yaml.j2" -o "./manifests/yamls/svc-clusterIP-host.yaml"

  # svc-clusterIP.yaml
  namespace=${FT_NAMESPACE} \
  http_clusterip_pod_svc_port=${HTTP_CLUSTERIP_POD_SVC_PORT} \
  iperf_clusterip_pod_svc_port=${IPERF_CLUSTERIP_POD_SVC_PORT} \
  j2 "./manifests/svc-clusterIP.yaml.j2" -o "./manifests/yamls/svc-clusterIP.yaml"

  # svc-nodePort-host.yaml
  namespace=${FT_NAMESPACE} \
  http_clusterip_host_svc_port=${HTTP_CLUSTERIP_HOST_SVC_PORT} \
  http_nodeport_host_svc_port=${HTTP_NODEPORT_HOST_SVC_PORT} \
  iperf_clusterip_host_svc_port=${IPERF_CLUSTERIP_HOST_SVC_PORT} \
  iperf_nodeport_host_svc_port=${IPERF_NODEPORT_HOST_SVC_PORT} \
  j2 "./manifests/svc-nodePort-host.yaml.j2" -o "./manifests/yamls/svc-nodePort-host.yaml"

  # svc-nodePort.yaml
  namespace=${FT_NAMESPACE} \
  http_clusterip_pod_svc_port=${HTTP_CLUSTERIP_POD_SVC_PORT} \
  http_nodeport_pod_svc_port=${HTTP_NODEPORT_POD_SVC_PORT} \
  iperf_clusterip_pod_svc_port=${IPERF_CLUSTERIP_POD_SVC_PORT} \
  iperf_nodeport_pod_svc_port=${IPERF_NODEPORT_POD_SVC_PORT} \
  j2 "./manifests/svc-nodePort.yaml.j2" -o "./manifests/yamls/svc-nodePort.yaml"
}
