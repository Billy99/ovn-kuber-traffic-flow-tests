#!/bin/bash

shopt -s expand_aliases

# Source the variables and functions in utilities.sh
. utilities.sh


#
# Default values (possible to override)
#
FT_NAMESPACE=${FT_NAMESPACE:-flow-test}

FULL_CLUSTERS="all"
CO_CLUSTERS="all"

if [ ! -z "$FT_FULL_CLUSTERS" ] ; then
  FULL_CLUSTERS=($FT_FULL_CLUSTERS)
fi
if [ ! -z "$FT_CO_CLUSTERS" ] ; then
  CO_CLUSTERS=($FT_CO_CLUSTERS)
fi

echo "Dumping FULL_CLUSTERS array:"
for j in "${!FULL_CLUSTERS[@]}"
do
  echo " FULL_CLUSTERS $j: ${FULL_CLUSTERS[$j]}"
done

echo "Dumping CO_CLUSTERS array:"
for k in "${!CO_CLUSTERS[@]}"
do
  echo " CO_CLUSTERS $k: ${CO_CLUSTERS[$k]}"
done
echo

# Retrieve all the managed clusters
CLUSTER_ARRAY=($(kubectl config get-contexts --no-headers=true | awk -F' ' '{print $3}'))
CLUSTER_LEN=${#CLUSTER_ARRAY[@]}


# Loop through all the Clusters and add normal Flow-Test deployment (Server Pods and Services)
# to the desired clusters
FULL_DEPLOYMENT=false
CO_DEPLOYMENT=false
EMPTY_CLUSTER1=
EMPTY_CLUSTER2=

echo "Looping through Cluster List ($CLUSTER_LEN entries):"
for i in "${!CLUSTER_ARRAY[@]}"
do
  echo " Analyzing Cluster $i: ${CLUSTER_ARRAY[$i]}"
  FOUND=false
  FULL_ALL_FOUND=false
  CO_ALL_FOUND=false

  kubectl config use-context ${CLUSTER_ARRAY[$i]} &>/dev/null

  # If it is the last Cluster in the list, and no Client Only has been
  # deployed, and Full Deployment has been deployed, then use it as a
  # Client Only (default case of FULL_CLUSTERS="all" and CO_CLUSTERS="all").
  if [ "$i" == "$(($CLUSTER_LEN-1))" ] && [ "${CO_DEPLOYMENT}" == false ] && [ "${FULL_DEPLOYMENT}" == true ] ; then
    echo "  Last Cluster and CO Deployment not found and Full Deployment deployed."
    echo "   Adding CO Deployment to ${CLUSTER_ARRAY[$i]}"
    echo "----------"
    FT_NAMESPACE=${FT_NAMESPACE} FT_EXPORT_SVC=false FT_CLIENTONLY=true ./launch.sh
    echo "----------"

    CO_DEPLOYMENT=true
    FOUND=true
  else
    # Loop through all requested Full Deployments
    for j in "${!FULL_CLUSTERS[@]}"
    do
      echo "  Testing FULL $j: ${FULL_CLUSTERS[$j]}"

      # Remember "all" was requested and apply later if not Client Only
      # not requested on this specific cluster
      if [ "${FULL_CLUSTERS[$j]}" == "all" ] ; then
        FULL_ALL_FOUND=true
      fi

      # If this Cluster has been requested for Full Deployment, then
      # deploy Full Deploymenr
      if [ "${FULL_CLUSTERS[$j]}" == "${CLUSTER_ARRAY[$i]}" ] ; then
        echo "   Adding Full Deployment to ${CLUSTER_ARRAY[$i]}"
        echo "----------"
        FT_NAMESPACE=${FT_NAMESPACE} FT_EXPORT_SVC=true FT_CLIENTONLY=false ./launch.sh
        echo "----------"

        FULL_DEPLOYMENT=true
        FOUND=true
        break
      fi
    done

    if [ "$FOUND" == false ] ; then
      # Loop through all requested CO Deployments
      for k in "${!CO_CLUSTERS[@]}"
      do
        echo "  Testing CO $k: ${CO_CLUSTERS[$k]}"

        # Remember "all" was requested and apply later if not Full Mode
        # did not request "all".
        if [ "${CO_CLUSTERS[$k]}" == "all" ] ; then
          CO_ALL_FOUND=true
        fi

        if [ "${CO_CLUSTERS[$k]}" == "${CLUSTER_ARRAY[$i]}" ] ; then
          echo "   Adding CO Deployment to ${CLUSTER_ARRAY[$i]}"
          echo "----------"
          FT_NAMESPACE=${FT_NAMESPACE} FT_EXPORT_SVC=false FT_CLIENTONLY=true ./launch.sh
          echo "----------"

          CO_DEPLOYMENT=true
          FOUND=true
          break
        fi
      done
    fi

    if [ "$FOUND" == false ] ; then
      if [ "$FULL_ALL_FOUND" == true ] ; then
        echo "   Adding Full Deployment to ${CLUSTER_ARRAY[$i]}"
        echo "----------"
        FT_NAMESPACE=${FT_NAMESPACE} FT_EXPORT_SVC=true FT_CLIENTONLY=false ./launch.sh
        echo "----------"

        FULL_DEPLOYMENT=true
        FOUND=true
      elif [ "$CO_ALL_FOUND" == true ] ; then
        echo "   Adding CO Deployment to ${CLUSTER_ARRAY[$i]}"
        echo "----------"
        FT_NAMESPACE=${FT_NAMESPACE} FT_EXPORT_SVC=false FT_CLIENTONLY=true ./launch.sh
        echo "----------"

        CO_DEPLOYMENT=true
        FOUND=true
      elif [ -z "$EMPTY_CLUSTER1" ] ; then
        EMPTY_CLUSTER1=${CLUSTER_ARRAY[$i]}
      elif [ -z "$EMPTY_CLUSTER2" ] ; then
        EMPTY_CLUSTER2=${CLUSTER_ARRAY[$i]}
      fi
    fi
  fi
done

if [ "$FULL_DEPLOYMENT" == false ] ; then
  if [ ! -z "$EMPTY_CLUSTER1" ] ; then
    EMPTY_CLUSTER=$EMPTY_CLUSTER1
    EMPTY_CLUSTER1=
  elif [ ! -z "$EMPTY_CLUSTER2" ] ; then
    EMPTY_CLUSTER=$EMPTY_CLUSTER2
    EMPTY_CLUSTER2=
  fi

  if [ ! -z "$EMPTY_CLUSTER" ] ; then
    echo "Full Deployment not found so using a random cluster Flow-Test was not deployed on."
    echo "   Adding Full Deployment to ${EMPTY_CLUSTER}"
    echo "----------"
    kubectl config use-context ${EMPTY_CLUSTER} &>/dev/null
    FT_NAMESPACE=${FT_NAMESPACE} FT_EXPORT_SVC=true FT_CLIENTONLY=false ./launch.sh
    echo "----------"

    FULL_DEPLOYMENT=true
    EMPTY_CLUSTER=
  else
    echo "ERROR: Full Deployment not found and no empty Clusters detected."
  fi
fi

if [ "$CO_DEPLOYMENT" == false ] ; then
  if [ ! -z "$EMPTY_CLUSTER1" ] ; then
    EMPTY_CLUSTER=$EMPTY_CLUSTER1
    EMPTY_CLUSTER1=
  elif [ ! -z "$EMPTY_CLUSTER2" ] ; then
    EMPTY_CLUSTER=$EMPTY_CLUSTER2
    EMPTY_CLUSTER2=
  fi

  if [ ! -z "$EMPTY_CLUSTER" ] ; then
    echo "CO Deployment not found so using a random cluster Flow-Test was not deployed on."
    echo "   Adding CO Deployment to ${EMPTY_CLUSTER}"
    echo "----------"
    kubectl config use-context ${EMPTY_CLUSTER} &>/dev/null
    FT_NAMESPACE=${FT_NAMESPACE} FT_EXPORT_SVC=false FT_CLIENTONLY=true ./launch.sh
    echo "----------"

    CO_DEPLOYMENT=true
    EMPTY_CLUSTER=
  else
    echo "ERROR: CO Deployment not found and no empty Clusters detected."
  fi
fi
