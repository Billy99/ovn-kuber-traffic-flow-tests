#!/bin/bash

# source the functions in labels.sh
. labels.sh

FT_LABEL_ACTION=add
manage_labels

kubectl apply -f svc_nodePort.yaml
kubectl apply -f serverPod-v4.yaml
kubectl apply -f clientDaemonSet.yaml

kubectl apply -f svc_host_nodePort.yaml
kubectl apply -f serverPod-host-v4.yaml
kubectl apply -f clientDaemonSet-host.yaml

