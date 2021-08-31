#!/bin/bash


# 
FT_REQ_SERVER_NODE=${FT_REQ_SERVER_NODE:-all}

FT_SERVER_NODE_LABEL=ft.ServerPod
FT_CLIENT_NODE_LABEL=ft.ClientPod
FT_SRIOV_NODE_LABEL=${FT_SRIOV_NODE_LABEL:-network.operator.openshift.io/external-openvswitch}

dump_labels() {
  echo "  Label Management:"
  echo "    FT_REQ_SERVER_NODE                 $FT_REQ_SERVER_NODE"
  echo "    FT_SERVER_NODE_LABEL               $FT_SERVER_NODE_LABEL"
  echo "    FT_CLIENT_NODE_LABEL               $FT_CLIENT_NODE_LABEL"
}

add_labels() {
  dump_labels

  local FOUND_SRIOV=false
  local FOUND_NODE=false

  local NODE_ARRAY=($(kubectl get nodes --no-headers=true | awk -F' ' '{print $1}'))
  for i in "${!NODE_ARRAY[@]}"
  do
    # Check for non-master (KIND clusters don't have "worker" role set)
    kubectl get node ${NODE_ARRAY[$i]}  --no-headers=true | awk -F' ' '{print $3}' | grep -q master
    if [ "$?" == 1 ]; then
      echo "${NODE_ARRAY[$i]} is worker"

      # Check for SR-IOV Nodes
      kubectl get nodes --show-labels --no-headers=true | grep ${NODE_ARRAY[$i]} | grep ${FT_SRIOV_NODE_LABEL}
      if [ "$?" == 0 ]; then
        # SR-IOV detected.
        # - Set LOCAL flag for server checks below.
        # - Update GLOBAL flag to return to caller so SR-IOV DaemonSet can be started.
        # - Assign label so SR-IOV Client DaemonSet Pod started on this Node.
        FOUND_SRIOV=true
        FT_SRIOV_CLIENT=true
        kubectl label nodes ${NODE_ARRAY[$i]} --overwrite=true $FT_CLIENT_NODE_LABEL=sriov
      else
        # SR-IOV NOT detected.
        # - Set LOCAL flag for server checks below.
        # - Update GLOBAL flag to return to caller so Non-SR-IOV DaemonSet can be started.
        # - Assign label so Normal Client DaemonSet Pod started on this Node.
        FOUND_SRIOV=false
        FT_NORMAL_CLIENT=true
        kubectl label nodes ${NODE_ARRAY[$i]} --overwrite=true $FT_CLIENT_NODE_LABEL=client
      fi

      if [ "$FOUND_NODE" == false ] && [ "$FT_REQ_SERVER_NODE" == all ] || [ "$FT_REQ_SERVER_NODE" == "${NODE_ARRAY[$i]}" ]; then
        echo "  Applying Server Label \"$FT_SERVER_NODE_LABEL\" to ${NODE_ARRAY[$i]}"
        kubectl label nodes ${NODE_ARRAY[$i]} --overwrite=true $FT_SERVER_NODE_LABEL=server
        FOUND_NODE=true
        if [ "$FOUND_SRIOV" == true ]; then
          FT_SRIOV_SERVER=true
        fi
      else
        kubectl label nodes ${NODE_ARRAY[$i]} --overwrite=true $FT_SERVER_NODE_LABEL=none
      fi
    fi
  done
}

query_labels() {
  dump_labels

  local NODE_ARRAY=($(kubectl get nodes --no-headers=true | awk -F' ' '{print $1}'))
  for i in "${!NODE_ARRAY[@]}"
  do
    # Check for client label: $FT_CLIENT_NODE_LABEL=client
    kubectl get node ${NODE_ARRAY[$i]} --show-labels --no-headers=true | awk -F' ' '{print $6}' | grep -q $FT_CLIENT_NODE_LABEL=client
    if [ "$?" == 0 ]; then
      if [ "$FT_NORMAL_CLIENT" == false ]; then
        echo "Detected Normal Client."
      fi
      FT_NORMAL_CLIENT=true
    fi

    # Check for client label: $FT_CLIENT_NODE_LABEL=sriov
    kubectl get node ${NODE_ARRAY[$i]} --show-labels --no-headers=true | awk -F' ' '{print $6}' | grep -q $FT_CLIENT_NODE_LABEL=sriov
    if [ "$?" == 0 ]; then
      if [ "$FT_SRIOV_CLIENT" == false ]; then
        echo "Detected SR-IOV Client."
      fi
      FT_SRIOV_CLIENT=true

      # Check for server label: $FT_CLIENT_NODE_LABEL=sriov
      kubectl get node ${NODE_ARRAY[$i]} --show-labels --no-headers=true | awk -F' ' '{print $6}' | grep -q $FT_SERVER_NODE_LABEL=server
      if [ "$?" == 0 ]; then
        if [ "$FT_SRIOV_SERVER" == false ]; then
          echo "Detected SR-IOV Server."
        fi
        FT_SRIOV_SERVER=true
      fi
    fi
  done
  if [ "$FT_SRIOV_SERVER" == false ]; then
    echo "Detected Normal Server."
  fi
}

del_labels() {
  local NODE_ARRAY=($(kubectl get nodes --no-headers=true | awk -F' ' '{print $1}'))
  for i in "${!NODE_ARRAY[@]}"
  do
    # Check for non-master (KIND clusters don't have "worker" role set)
    kubectl get node ${NODE_ARRAY[$i]}  --no-headers=true | awk -F' ' '{print $3}' | grep -q master
    if [ "$?" == 1 ]; then
      echo "${NODE_ARRAY[$i]} is worker"

      echo "  Removing Server Label \"$FT_SERVER_NODE_LABEL\" from ${NODE_ARRAY[$i]}"
      kubectl label nodes ${NODE_ARRAY[$i]} $FT_SERVER_NODE_LABEL- >/dev/null
      echo "  Removing Client Label \"$FT_CLIENT_NODE_LABEL\" from ${NODE_ARRAY[$i]}"
      kubectl label nodes ${NODE_ARRAY[$i]} $FT_CLIENT_NODE_LABEL- >/dev/null
    fi
  done
}
