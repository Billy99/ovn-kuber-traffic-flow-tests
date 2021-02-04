#!/bin/bash

# source the functions in labels.sh
. labels.sh

FT_LABEL_ACTION=delete
manage_labels

kubectl delete -f clientDaemonSet.yaml
kubectl delete -f serverPod-v4.yaml
kubectl delete -f svc_nodePort.yaml

kubectl delete -f clientDaemonSet-host.yaml
kubectl delete -f serverPod-host-v4.yaml
kubectl delete -f svc_host_nodePort.yaml

