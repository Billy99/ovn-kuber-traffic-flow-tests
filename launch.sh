#!/bin/bash

# source the functions in labels.sh
. labels.sh

FT_LABEL_ACTION=add
FT_SMARTNIC_SERVER=false
FT_NORMAL_CLIENT=false
FT_SMARTNIC_CLIENT=false
manage_labels

if [ "$FT_SMARTNIC_SERVER" == true ] || [ "$FT_SMARTNIC_CLIENT" == true ]; then
  kubectl create -f yamls/netAttachDef-smartNic.yaml
fi

# Create Cluster Networked Pods and Services
kubectl apply -f yamls/svc-nodePort.yaml
kubectl apply -f yamls/svc-clusterIP.yaml

# Launch "smartnic" daemonset as well if node has it enabled 
if [ "$FT_SMARTNIC_SERVER" == true ]; then
  kubectl apply -f yamls/server-pod-v4-smartNic.yaml
else
  kubectl apply -f yamls/server-pod-v4.yaml
fi

if [ "$FT_NORMAL_CLIENT" == true ]; then
  kubectl apply -f yamls/client-daemonSet.yaml
fi
if [ "$FT_SMARTNIC_CLIENT" == true ]; then
  kubectl apply -f yamls/client-daemonSet-smartNic.yaml
fi

# Create Host networked Pods and Services
kubectl apply -f yamls/svc-nodePort-host.yaml
kubectl apply -f yamls/svc-clusterIP-host.yaml
kubectl apply -f yamls/server-pod-v4-host.yaml
kubectl apply -f yamls/client-daemonSet-host.yaml
