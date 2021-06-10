#!/bin/bash

# source the functions in labels.sh
. labels.sh

# Call manage_labels() with ADD again to set flags so know what to delete
FT_LABEL_ACTION=add
FT_SMARTNIC_SERVER=false
FT_NORMAL_CLIENT=false
FT_SMARTNIC_CLIENT=false
manage_labels

# Delete normal Pods and Service
if [ "$FT_NORMAL_CLIENT" == true ]; then
  kubectl delete -f ./manifests/yamls/client-daemonSet.yaml
fi
if [ "$FT_SMARTNIC_CLIENT" == true ]; then
  kubectl delete -f ./manifests/yamls/client-daemonSet-smartNic.yaml
fi

if [ "$FT_SMARTNIC_SERVER" == true ]; then
  kubectl delete -f ./manifests/yamls/iperf-server-pod-v4-smartNic.yaml
  kubectl delete -f ./manifests/yamls/http-server-pod-v4-smartNic.yaml
else
  kubectl delete -f ./manifests/yamls/iperf-server-pod-v4.yaml
  kubectl delete -f ./manifests/yamls/http-server-pod-v4.yaml
fi

kubectl delete -f ./manifests/yamls/svc-nodePort.yaml


# Delete HOST backed Pods and Service
kubectl delete -f ./manifests/yamls/svc-nodePort-host.yaml
kubectl delete -f ./manifests/yamls/svc-clusterIP-host.yaml
kubectl delete -f ./manifests/yamls/iperf-server-pod-v4-host.yaml
kubectl delete -f ./manifests/yamls/http-server-pod-v4-host.yaml
kubectl delete -f ./manifests/yamls/client-daemonSet-host.yaml


if [ "$FT_SMARTNIC_SERVER" == true ] || [ "$FT_SMARTNIC_CLIENT" == true ]; then
  kubectl delete -f ./manifests/yamls/netAttachDef-sriov.yaml
fi

kubectl delete -f ./manifests/yamls/svc-nodePort.yaml
kubectl delete -f ./manifests/yamls/svc-clusterIP.yaml

FT_LABEL_ACTION=delete
manage_labels

rm -rf ovn-traces/*
