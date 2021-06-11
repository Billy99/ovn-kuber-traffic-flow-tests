#!/bin/bash

install_j2_renderer() {

  j2 -v  &>/dev/null

  if [ $? != 0 ]; then
    # ensure j2 renderer installed
    pip install wheel --user
    pip freeze | grep j2cli || pip install j2cli[yaml] --user
    export PATH=~/.local/bin:$PATH
  fi
}

generate_yamls() {

  #
  # Client Pods
  #

  # client-daemonSet-host.yaml
  test_image=${TEST_IMAGE} \
  j2 "./manifests/client-daemonSet-host.yaml.j2" -o "./manifests/yamls/client-daemonSet-host.yaml"

  # client-daemonSet-smartNic.yaml
  sriov_resource_name=${SRIOV_RESOURCE_NAME} \
  test_image=${TEST_IMAGE} \
  j2 "./manifests/client-daemonSet-smartNic.yaml.j2" -o "./manifests/yamls/client-daemonSet-smartNic.yaml"

  # client-daemonSet.yaml
  test_image=${TEST_IMAGE} \
  j2 "./manifests/client-daemonSet.yaml.j2" -o "./manifests/yamls/client-daemonSet.yaml"

  #
  # http Server Pods
  #

  # http-server-pod-v4-host.yaml
  http_clusterip_host_svc_port=${HTTP_CLUSTERIP_HOST_SVC_PORT} \
  j2 "./manifests/http-server-pod-v4-host.yaml.j2" -o "./manifests/yamls/http-server-pod-v4-host.yaml"

  # http-server-pod-v4-smartNic
  sriov_resource_name=${SRIOV_RESOURCE_NAME} \
  http_clusterip_pod_svc_port=${HTTP_CLUSTERIP_POD_SVC_PORT} \
  j2 "./manifests/http-server-pod-v4-smartNic.yaml.j2" -o "./manifests/yamls/http-server-pod-v4-smartNic.yaml"

  # http-server-pod-v4.yaml
  http_clusterip_pod_svc_port=${HTTP_CLUSTERIP_POD_SVC_PORT} \
  j2 "./manifests/http-server-pod-v4.yaml.j2" -o "./manifests/yamls/http-server-pod-v4.yaml"

  #
  # iperf Server Pods
  #

  # iperf-server-pod-v4-host.yaml
  test_image=${TEST_IMAGE} \
  iperf_clusterip_host_svc_port=${IPERF_CLUSTERIP_HOST_SVC_PORT} \
  j2 "./manifests/iperf-server-pod-v4-host.yaml.j2" -o "./manifests/yamls/iperf-server-pod-v4-host.yaml"

  # iperf-server-pod-v4-smartNic.yaml
  sriov_resource_name=${SRIOV_RESOURCE_NAME} \
  test_image=${TEST_IMAGE} \
  iperf_clusterip_pod_svc_port=${IPERF_CLUSTERIP_POD_SVC_PORT} \
  j2 "./manifests/iperf-server-pod-v4-smartNic.yaml.j2" -o "./manifests/yamls/iperf-server-pod-v4-smartNic.yaml"

  # iperf-server-pod-v4.yaml
  test_image=${TEST_IMAGE} \
  iperf_clusterip_pod_svc_port=${IPERF_CLUSTERIP_POD_SVC_PORT} \
  j2 "./manifests/iperf-server-pod-v4.yaml.j2" -o "./manifests/yamls/iperf-server-pod-v4.yaml"


  #
  # Network-Attachment-Definitions
  #

  # netAttachDef-sriov.yaml
  sriov_resource_name=${SRIOV_RESOURCE_NAME} \
  iperf_clusterip_host_svc_port=${IPERF_CLUSTERIP_HOST_SVC_PORT} \
  j2 "./manifests/netAttachDef-sriov.yaml.j2" -o "./manifests/yamls/netAttachDef-sriov.yaml"


  #
  # Services
  #

  # svc-clusterIP.yaml
  http_clusterip_host_svc_port=${HTTP_CLUSTERIP_HOST_SVC_PORT} \
  iperf_clusterip_host_svc_port=${IPERF_CLUSTERIP_HOST_SVC_PORT} \
  j2 "./manifests/svc-clusterIP-host.yaml.j2" -o "./manifests/yamls/svc-clusterIP-host.yaml"

  # svc-clusterIP.yaml
  http_clusterip_pod_svc_port=${HTTP_CLUSTERIP_POD_SVC_PORT} \
  iperf_clusterip_pod_svc_port=${IPERF_CLUSTERIP_POD_SVC_PORT} \
  j2 "./manifests/svc-clusterIP.yaml.j2" -o "./manifests/yamls/svc-clusterIP.yaml"

  # svc-nodePort-host.yaml
  http_clusterip_host_svc_port=${HTTP_CLUSTERIP_HOST_SVC_PORT} \
  http_nodeport_host_svc_port=${HTTP_NODEPORT_HOST_SVC_PORT} \
  iperf_clusterip_host_svc_port=${IPERF_CLUSTERIP_HOST_SVC_PORT} \
  iperf_nodeport_host_svc_port=${IPERF_NODEPORT_HOST_SVC_PORT} \
  j2 "./manifests/svc-nodePort-host.yaml.j2" -o "./manifests/yamls/svc-nodePort-host.yaml"

  # svc-nodePort.yaml
  http_clusterip_pod_svc_port=${HTTP_CLUSTERIP_POD_SVC_PORT} \
  http_nodeport_pod_svc_port=${HTTP_NODEPORT_POD_SVC_PORT} \
  iperf_clusterip_pod_svc_port=${IPERF_CLUSTERIP_POD_SVC_PORT} \
  iperf_nodeport_pod_svc_port=${IPERF_NODEPORT_POD_SVC_PORT} \
  j2 "./manifests/svc-nodePort.yaml.j2" -o "./manifests/yamls/svc-nodePort.yaml"
}
