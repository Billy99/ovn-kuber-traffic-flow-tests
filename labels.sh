#!/bin/bash


# 
FT_LABEL_ACTION=${FT_LABEL_ACTION:-}
FT_REQ_SERVER_NODE=${FT_REQ_SERVER_NODE:-all}

FT_SERVER_NODE_LABEL=ft.ServerPod

manage_labels() {
  echo "Label Management:"
  echo "  FT_LABEL_ACTION            $FT_LABEL_ACTION"
  echo "  FT_REQ_SERVER_NODE         $FT_REQ_SERVER_NODE"
  echo "  FT_SERVER_NODE_LABEL       $FT_SERVER_NODE_LABEL"

  FOUND_NODE=false
  NODE_ARRAY=($(kubectl get nodes --no-headers=true | awk -F' ' '{print $1}'))
  for i in "${!NODE_ARRAY[@]}"
  do
    if [ "$FT_LABEL_ACTION" == add ]; then
      # Check for non-master (KIND clusters don't have "worker" role set)
      kubectl get node ${NODE_ARRAY[$i]}  --no-headers=true | awk -F' ' '{print $3}' | grep -q master
      if [ "$?" == 1 ]; then
        echo "${NODE_ARRAY[$i]} is worker"
        if [ "$FOUND_NODE" == false ] && [ "$FT_REQ_SERVER_NODE" == all ] || [ "$FT_REQ_SERVER_NODE" == "${NODE_ARRAY[$i]}" ]; then
          echo "  Applying Server Label \"$FT_SERVER_NODE_LABEL\" to ${NODE_ARRAY[$i]}"
          kubectl label nodes ${NODE_ARRAY[$i]} $FT_SERVER_NODE_LABEL=server
          FOUND_NODE=true
        else
          kubectl label nodes ${NODE_ARRAY[$i]} $FT_SERVER_NODE_LABEL=none
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
      fi
    fi
  done
}