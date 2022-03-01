#!/bin/bash

shopt -s expand_aliases

# Source the functions in utilities.sh
. utilities.sh

# Make sure kubectl is installed. Create an alias if not.
# This needs to be done before other files are sourced.
test_for_kubectl

# Save Context to restore when done.
ORIG_CONTEXT=$(kubectl config current-context)

#
# Default values (possible to override)
#
FT_NAMESPACE=${FT_NAMESPACE:-flow-test}
HTTP_SERVER_HOST_POD_NAME=${HTTP_SERVER_HOST_POD_NAME:-ft-http-server-host-v4}


# Retrieve all the managed clusters
CLUSTER_ARRAY=($(kubectl config get-contexts --no-headers=true | awk -F' ' '{print $3}'))

echo "Looping through Cluster List ($CLUSTER_LEN entries):"
for i in "${!CLUSTER_ARRAY[@]}"
do
    echo "Managing Cluster $i: ${CLUSTER_ARRAY[$i]}"
    kubectl config use-context ${CLUSTER_ARRAY[$i]} &>/dev/null

    # To see if Flow-Test deployed on Cluster
    kubectl get --no-headers=true namespaces ${FT_NAMESPACE} &>/dev/null
    if [ "$?" == 0 ] ; then
      # Look for Host backer Server pod, in Client Only it shouldn't be there
      TEST_SERVER=`kubectl get pods -n ${FT_NAMESPACE} | grep -o "$HTTP_SERVER_HOST_POD_NAME"`
      if [ -z "${TEST_SERVER}" ]; then
        echo " Deleting CO Deployment from Cluster ${CLUSTER_ARRAY[$i]}"
        echo "----------"
        FT_NAMESPACE=${FT_NAMESPACE} FT_EXPORT_SVC=false FT_CLIENTONLY=true ./cleanup.sh
        echo "----------"
      else
        echo " Deleting Full Deployment from Cluster ${CLUSTER_ARRAY[$i]}"
        echo "----------"
        FT_NAMESPACE=${FT_NAMESPACE} FT_EXPORT_SVC=true FT_CLIENTONLY=false ./cleanup.sh
        echo "----------"
      fi
      echo " Testing for remaining objects"
      echo "  kubectl get all -A | grep \"ft\""
      kubectl get all -A | grep "ft"
      echo "  kubectl get all -A | grep \"flow\""
      kubectl get all -A | grep "flow"
      echo
    else
      echo " Flow-Test not deployed on Cluster ${CLUSTER_ARRAY[$i]}"
    fi
done

# Restore context to original.
kubectl config use-context ${ORIG_CONTEXT}
