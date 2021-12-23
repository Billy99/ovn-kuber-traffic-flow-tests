#!/bin/bash

shopt -s expand_aliases

# Source the functions in utilities.sh
. utilities.sh

# Make sure kubectl is installed. Create an alias if not.
# This needs to be done before other files are sourced.
test_for_kubectl


#
# Default values (possible to override)
#
FT_NAMESPACE=${FT_NAMESPACE:-flow-test}
FT_SVC_QUALIFIER=${FT_SVC_QUALIFIER:-".${FT_NAMESPACE}.svc.clusterset.local"}
HTTP_SERVER_HOST_POD_NAME=${HTTP_SERVER_HOST_POD_NAME:-ft-http-server-host-v4}


# Retrieve all the managed clusters
CLUSTER_ARRAY=($(kubectl config get-contexts --no-headers=true | awk -F' ' '{print $3}'))

echo "Looping through Cluster List ($CLUSTER_LEN entries):"
for i in "${!CLUSTER_ARRAY[@]}"
do
    echo " Managing Cluster $i: ${CLUSTER_ARRAY[$i]}"
    kubectl config use-context ${CLUSTER_ARRAY[$i]} &>/dev/null

    # To see if Flow-Test deployed on Cluster
    kubectl get --no-headers=true namespaces ${FT_NAMESPACE} &>/dev/null
    if [ "$?" == 0 ] ; then
      # Look for Host backer Server pod, in Client Only it shouldn't be there
      TEST_SERVER=`kubectl get pods -n ${FT_NAMESPACE} | grep -o "$HTTP_SERVER_HOST_POD_NAME"`
      if [ -z "${TEST_SERVER}" ]; then
        echo "  Testing Remote Services on CO Deployment on Cluster ${CLUSTER_ARRAY[$i]}"
        FT_NAMESPACE=${FT_NAMESPACE} FT_SVC_QUALIFIER=${FT_SVC_QUALIFIER} FT_NOTES=false ./test.sh
      else
        echo "  Skipping testing on Full Deployment on Cluster ${CLUSTER_ARRAY[$i]}"
      fi
    else
      echo "  Flow-Test not deployed on Cluster ${CLUSTER_ARRAY[$i]}"
    fi
done
