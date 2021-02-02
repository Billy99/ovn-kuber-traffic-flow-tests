
# OVN-Kubernetes Traffic Flow Test Scripts (ovn-kuber-traffic-flow-tests)

This repository contains the yaml files and test scripts to test all the traffic flows in an OVN-Kubernetes cluster.

## Table of Contents

- [Different Traffic Flows Tested](#different-traffic-flows-tested)
- [Cluster Deployment](#cluster-deployment)
	- [Upstream OVN-Kubernetes and KIND](#upstream-ovn-kubernetes-and-kind)
	- [OVN-Kubernetes Running on OCP](#ovn-kubernetes-running-on-ocp)
- [Test Pod Deployment](#test-pod-deployment)
- [Test Script Usage](#test-script-usage)


## Different Traffic Flows Tested

1. Typical Pod to Pods traffic (using cluster subnet)
   * Pod to Pod (Same Node)
   * Pod to Pod (Different Node)
1. Pod -> Cluster IP Service traffic
   * Pod to Cluster IP (Same Node)
   * Pod to Cluster IP (Different Node)
1. Pod -> NodePort Service traffic
   * Pod -> NodePort Service traffic (pod backend - Same Node)
   * Pod -> NodePort Service traffic (pod backend - Different Node)
   * Pod -> NodePort Service traffic (host networked pod backend - Same Node)
   * Pod -> NodePort Service traffic (host networked pod backend - Different Node)
1. Pod -> External Network (egress traffic)
1. Host -> Cluster IP Service traffic (pod backend)
   * Host -> Cluster IP Service traffic (pod backend - Same Node)
   * Host -> Cluster IP Service traffic (pod backend - Different Node)
1. Host -> NodePort Service traffic (pod backend)
   * Host -> NodePort Service traffic (pod backend - Same Node)
   * Host -> NodePort Service traffic (pod backend - Different Node)
1. Host -> Cluster IP Service traffic (host networked pod backend)
   * Host -> Cluster IP Service traffic (host networked pod backend - Same Node)
   * Host -> Cluster IP Service traffic (host networked pod backend - Different Node)
1. Host -> NodePort Service traffic (host networked pod backend)
   * Host -> NodePort Service traffic (host networked pod backend - Same Node)
   * Host -> NodePort Service traffic (host networked pod backend - Different Node)
1. External Network Traffic -> NodePort/External IP Service (ingress traffic)
   * External Network Traffic -> NodePort/External IP Service (ingress traffic - pod backend)
   * External Network Traffic -> NodePort/External IP Service (ingress traffic - host networked pod backend)
1. External Network Traffic -> Pods (multiple external GW traffic)
   * NOTE: Special Use-Case for customer


## Cluster Deployment

### Upstream OVN-Kubernetes and KIND

To test with upstream OVN-Kubernetes and KIND:
```
cd $GOPATH/src/github.com/ovn-org/ovn-kubernetes/contrib/
./kind.sh -ha -wk 4
```

With this KIND Cluster:
* Nodes `ovn-control-plane`, `ovn-worker` and `ovn-worker2` are master nodes.
* Nodes `ovn-worker3`, `ovn-worker4`, `ovn-worker5` and `ovn-worker6` are worker nodes.

### OVN-Kubernetes Running on OCP

**TBD:** This section will be updated once tested.


## Test Pod Deployment

Test setup is as follows, create POD backed set of resources:
* Run pod-backed *'client'* (DaemonSet) on every node.
* Run one instance of a pod-backed *'server'*.
* Create a NodePort Service for the pod-backed *'server'* using NodePort 30080.

Create Host-POD backed set of resources:
* Run host-backed *'client'* (DaemonSet) on every node.
* Run one instance of a host-backed *'server'*.
* Create a NodePort Service for the host-backed *'server'* using NodePort 30081.

The script finds a *'client'* pod on the *'Same Node'* as the pod-backed *'server'* and
finds a *'client'* pod on a *'Different Node'* from the pod-backed *'server'*. Repeats for
the host-backer *'server'*.

Once the *'client'* pods (LOCAL and REMOTE, POD and HOST) and IP addresses have been
collected, the script runs curl commands in different combinations to test each of
traffic flows.


Create *'client'* DaemonSets, the different *'server'* instances, and the NodePort Services:

```
cd ~/src/ovn-kuber-traffic-flow-tests/

kubectl apply -f svc_nodePort.yaml
kubectl apply -f serverPod-v4.yaml
kubectl apply -f clientDaemonSet.yaml

kubectl apply -f svc_host_nodePort.yaml
kubectl apply -f serverPod-host-v4.yaml
kubectl apply -f clientDaemonSet-host.yaml

./test.sh
```

Teardown:

```
kubectl delete -f clientDaemonSet.yaml
kubectl delete -f serverPod-v4.yaml
kubectl delete -f svc_nodePort.yaml

kubectl delete -f clientDaemonSet-host.yaml
kubectl delete -f serverPod-host-v4.yaml
kubectl delete -f svc_host_nodePort.yaml
```

## Test Script Usage

To run all the tests, simply run the script.
* All the hard-coded values are printed to the screen (and can be overwritten). 
* Then all the queried values, like Pod Names and IP addresses are printed.
* Each test is run with actual command executed printed to the screen.
* <span style="color:green">**SUCCESS**</span> or <span style="color:red">**FAILED**</span> is then printed.

```
$ ./test.sh

Default/Override Values:
 Test Control:
  DEBUG_TEST                   false
  TEST_CASE (0 means all)      0
  VERBOSE                      false
 From YAML Files:
  SERVER_POD_NAME              web-server-node-v4
  SERVER_HOST_POD_NAME         web-server-host-node-v4
  CLIENT_POD_NAME_PREFIX       web-client-pod
  SERVER_POD_PORT              8080
  SERVER_HOST_POD_PORT         8081
  NODEPORT_SVC_NAME            my-web-service-node-v4
  NODEPORT_HOST_SVC_NAME       my-web-service-host-node-v4
  NODEPORT_POD_PORT            30080
  NODEPORT_HOST_PORT           30081
  POD_SERVER_STRING            Server - Pod Backend Reached
  HOST_SERVER_STRING           Server - Host Backend Reached
  EXTERNAL_SERVER_STRING       The document has moved
 Cluster Node Names:
  REMOTE_CLIENT_NODE_DEFAULT   ovn-worker4
  REMOTE_CLIENT_NODE_BACKUP    ovn-worker5
 External Access:
  EXTERNAL_IP                  8.8.8.8
  EXTERNAL_URL                 google.com
Queried Values:
 Pod Backed:
  SERVER_IP                    10.244.1.9
  SERVER_NODE                  ovn-worker5
  LOCAL_CLIENT_NODE            ovn-worker5
  LOCAL_CLIENT_POD             web-client-pod-qcf52
  REMOTE_CLIENT_NODE           ovn-worker4
  REMOTE_CLIENT_POD            web-client-pod-fq7fx
  NODEPORT_CLUSTER_IPV4        10.96.228.161
  NODEPORT_EXTERNAL_IPV4       10.244.1.9
 Host backed:
  SERVER_HOST_IP               172.18.0.8
  SERVER_HOST_NODE             ovn-worker6
  REMOTE_CLIENT_HOST_NODE      ovn-worker4
  LOCAL_CLIENT_HOST_POD        web-client-pod-z8gmj
  REMOTE_CLIENT_HOST_POD       web-client-pod-fq7fx
  NODEPORT_HOST_CLUSTER_IPV4   10.96.58.164
  NODEPORT_HOST_EXTERNAL_IPV4  172.18.0.8


FLOW 01: Typical Pod to Pod traffic (using cluster subnet)
----------------------------------------------------------

*** Pod to Pod (Same Node) ***
kubectl exec -it web-client-pod-qcf52 -- curl "http://10.244.1.9:8080/"
SUCCESS



*** Pod to Pod (Different Node) ***
kubectl exec -it web-client-pod-fq7fx -- curl "http://10.244.1.9:8080/"
SUCCESS



FLOW 02: Pod -> Cluster IP Service traffic
------------------------------------------

*** Pod -> Cluster IP Service traffic (Same Node) ***
kubectl exec -it web-client-pod-qcf52 -- curl "http://10.96.228.161:8080/"
SUCCESS



*** Pod -> Cluster IP Service traffic (Different Node) ***
kubectl exec -it web-client-pod-fq7fx -- curl "http://10.96.228.161:8080/"
SUCCESS

:
```

Below are some commonly used overrides:
* If a single test needs to be run (this is at the FLOW level):
```
TEST_CASE=3 ./test.sh
```
* For readability, the output of the `curl` is masked. This can be unmasked for debugging:
```
TEST_CASE=3 VERBOSE=true ./test.sh
```
* If the `curl` fails, for more debugging, some of the FLOWs also have associated `ping` commands, or `curl` to port 80 instead of the NodePort:
```
DEBUG_TEST=true TEST_CASE=3 VERBOSE=true ./test.sh
```
<br>

There are a couple of sub-FLOWs that are failing and not sure if they are suppose to work or not, so there are some test-case notes for those, for example <span style="color:blue">**ERROR - NAME:30080 works but IP:30080 doesn't**</span>:
```
$ DEBUG_TEST=true TEST_CASE=3 VERBOSE=true ./test.sh

:

FLOW 03: Pod -> NodePort Service traffic (pod/host backend)
-----------------------------------------------------------

*** Pod -> NodePort Service traffic (pod backend - Same Node) ***
ERROR - NAME:30080 works but IP:30080 doesn't
kubectl exec -it web-client-pod-qcf52 -- curl "http://10.244.1.9:30080/"
command terminated with exit code 7
FAILED

kubectl exec -it web-client-pod-qcf52 -- curl "http://my-web-service-node-v4:30080/"
SUCCESS



*** Pod -> NodePort Service traffic (pod backend - Different Node) ***
ERROR - NAME:30080 works but IP:30080 doesn't
kubectl exec -it web-client-pod-fq7fx -- curl "http://10.244.1.9:30080/"
command terminated with exit code 7
FAILED

kubectl exec -it web-client-pod-fq7fx -- curl "http://my-web-service-node-v4:30080/"
SUCCESS

:
```