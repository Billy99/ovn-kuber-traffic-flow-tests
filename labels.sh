#!/bin/bash


# 
FT_LABEL_ACTION=${FT_LABEL_ACTION:-}
FT_REQ_SERVER_NODE=${FT_REQ_SERVER_NODE:-all}

FT_SERVER_NODE_LABEL=ft.ServerPod
FT_CLIENT_NODE_LABEL=ft.ClientPod
FT_SMARTNIC_LABEL=${FT_SMARTNIC_LABEL:-network.operator.openshift.io/external-openvswitch}

dump_labels() {
  echo "  Label Management:"
  echo "    FT_LABEL_ACTION                    $FT_LABEL_ACTION"
  echo "    FT_REQ_SERVER_NODE                 $FT_REQ_SERVER_NODE"
  echo "    FT_SERVER_NODE_LABEL               $FT_SERVER_NODE_LABEL"
  echo "    FT_CLIENT_NODE_LABEL               $FT_CLIENT_NODE_LABEL"
}

manage_labels() {
  dump_labels

  local FOUND_SMARTNIC=false
  local FOUND_NODE=false

  local NODE_ARRAY=($(kubectl get nodes --no-headers=true | awk -F' ' '{print $1}'))
  for i in "${!NODE_ARRAY[@]}"
  do
    if [ "$FT_LABEL_ACTION" == add ]; then
      # Check for non-master (KIND clusters don't have "worker" role set)
      kubectl get node ${NODE_ARRAY[$i]}  --no-headers=true | awk -F' ' '{print $3}' | grep -q master
      if [ "$?" == 1 ]; then
        echo "${NODE_ARRAY[$i]} is worker"

        # Check for Offload to SmartNIC
        kubectl get nodes --show-labels --no-headers=true | grep ${NODE_ARRAY[$i]} | grep ${FT_SMARTNIC_LABEL}
        if [ "$?" == 0 ]; then
          # SmartNic detected.
          # - Set LOCAL flag for server checks below.
          # - Update GLOBAL flag to return to caller so SmartNic DaemonSet can be started.
          # - Assign label so SmartNic Client DaemonSet Pod started on this Node.
          FOUND_SMARTNIC=true
          FT_SMARTNIC_CLIENT=true
          kubectl label nodes ${NODE_ARRAY[$i]} --overwrite=true $FT_CLIENT_NODE_LABEL=smartnic
        else
          # SmartNic detected.
          # - Set LOCAL flag for server checks below.
          # - Update GLOBAL flag to return to caller so Non-SmartNic DaemonSet can be started.
          # - Assign label so Normal Client DaemonSet Pod started on this Node.
          FOUND_SMARTNIC=false
          FT_NORMAL_CLIENT=true
          kubectl label nodes ${NODE_ARRAY[$i]} --overwrite=true $FT_CLIENT_NODE_LABEL=client
        fi

        if [ "$FOUND_NODE" == false ] && [ "$FT_REQ_SERVER_NODE" == all ] || [ "$FT_REQ_SERVER_NODE" == "${NODE_ARRAY[$i]}" ]; then
          echo "  Applying Server Label \"$FT_SERVER_NODE_LABEL\" to ${NODE_ARRAY[$i]}"
          kubectl label nodes ${NODE_ARRAY[$i]} --overwrite=true $FT_SERVER_NODE_LABEL=server
          FOUND_NODE=true
          if [ "$FOUND_SMARTNIC" == true ]; then
            FT_SMARTNIC_SERVER=true
          fi
        else
          kubectl label nodes ${NODE_ARRAY[$i]} --overwrite=true $FT_SERVER_NODE_LABEL=none
        fi
      fi
    fi

    if [ "$FT_LABEL_ACTION" == delete ]; then
      # Check for non-master (KIND clusters don't have "worker" role set)
      kubectl get node ${NODE_ARRAY[$i]}  --no-headers=true | awk -F' ' '{print $3}' | grep -q master
      if [ "$?" == 1 ]; then
        echo "${NODE_ARRAY[$i]} is worker"

        echo "  Removing Server Label \"$FT_SERVER_NODE_LABEL\" from ${NODE_ARRAY[$i]}"
        kubectl label nodes ${NODE_ARRAY[$i]} $FT_SERVER_NODE_LABEL- >/dev/null
        echo "  Removing Client Label \"$FT_CLIENT_NODE_LABEL\" from ${NODE_ARRAY[$i]}"
        kubectl label nodes ${NODE_ARRAY[$i]} $FT_CLIENT_NODE_LABEL- >/dev/null
      fi
    fi
  done
}
