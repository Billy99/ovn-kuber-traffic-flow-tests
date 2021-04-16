
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

Deploy OCP as normal.

In the SR-IOV Lab, the Nodes are as follows:
* Nodes `sriov-master-0`, `sriov-master-1` and `sriov-master-2` are master nodes.
* Nodes `sriov-worker-0` and `sriov-worker-1` are worker nodes.


## Test Pod Deployment

Test setup is as follows, create POD backed set of resources:
* Run pod-backed *'client'* (DaemonSet) on every node.
* Run one instance of a pod-backed *'server'*.
* Create a NodePort Service for the pod-backed *'server'* using NodePort 30080.

Create Host-POD backed set of resources:
* Run host-backed *'client'* (DaemonSet) on every node.
* Run one instance of a host-backed *'server'*.
* Create a NodePort Service for the host-backed *'server'* using NodePort 30081.

The script finds:
* *'client'* pod on the *'Same Node'* as the pod-backed *'server'*
* *'client'* pod on a *'Different Node'* from the pod-backed *'server'*
* *'client'* pod on the *'Same Node'* as the host-pod-backed *'server'*
* *'client'* pod on a *'Different Node'* from the host-pod-backed *'server'*

Once the *'client'* pods (LOCAL and REMOTE, POD and HOST) and IP addresses have been
collected, the script runs curl commands in different combinations to test each of
traffic flows.


Create *'client'* DaemonSets, the different *'server'* instances, and the NodePort Services:

```
cd ~/src/ovn-kuber-traffic-flow-tests/

./launch.sh
```

Each *'server'* (pod backed and host-networked pod backed) needs to be on the same node.
So the setup scripts use labels to achieve this. The default is to schedule the servers
on the first worker node detected. If there is a particular node the *'server'* pods
should run on, for example on an OVS Hardware offloaded node, then use the following
environment variable to force each *'server'* pod on a desired node ('FT_' stands for
Flow Test).  *NOTE:* This needs to be set before the pods are launched.

```
FT_REQ_SERVER_NODE=ovn-worker4 \
./launch.sh

-- OR --

export FT_REQ_SERVER_NODE=ovn-worker4
./launch.sh
```

Along the same lines, the *'launch.sh'* script creates a *'client'* (pod backed and
host-networked pod backed) on each worker node. The *'test.sh'* script sends packets from
the node on the same node the *'server'* pods are running on (determined as described above)
and a remote node (node *'server'* pods are NOT running on). If there is a particular node
that should be marked as the *' remote client'* node, for example on an OVS Hardware
offloaded node, then use the following environment variable to force the *'test.sh'* script
to pick as the desired node.  *NOTE:* This needs to be set before the *'test.sh'* script is
run and can be changed between each test run.

```
FT_REQ_REMOTE_CLIENT_NODE=ovn-worker3 \
./test.sh

-- OR --

export FT_REQ_REMOTE_CLIENT_NODE=ovn-worker3
./test.sh
```


To teardown the test setup:

```
cd ~/src/ovn-kuber-traffic-flow-tests/

./cleanup.sh
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
    TEST_CASE (0 means all)         0
    VERBOSE                         false
    OVN_TRACE                       true
    FT_NOTES                        true
    CURL_CMD                        curl -m 5
    FT_REQ_REMOTE_CLIENT_NODE       all
  From YAML Files:
    SERVER_POD_NAME                 web-server-node-v4
    SERVER_HOST_POD_NAME            web-server-host-node-v4
    CLIENT_POD_NAME_PREFIX          web-client-pod
    SERVER_POD_PORT                 8080
    SERVER_HOST_POD_PORT            8081
    CLUSTERIP_SVC_NAME              web-service-clusterip-v4
    CLUSTERIP_HOST_SVC_NAME         web-service-clusterip-host-v4
    NODEPORT_SVC_NAME               my-web-service-node-v4
    NODEPORT_HOST_SVC_NAME          my-web-service-host-node-v4
    NODEPORT_POD_PORT               30080
    NODEPORT_HOST_PORT              30081
    POD_SERVER_STRING               Server - Pod Backend Reached
    HOST_SERVER_STRING              Server - Host Backend Reached
    EXTERNAL_SERVER_STRING          The document has moved
  External Access:
    EXTERNAL_IP                     8.8.8.8
    EXTERNAL_URL                    google.com
Queried Values:
  Pod Backed:
    SERVER_IP                       10.244.0.5
    SERVER_NODE                     ovn-worker6
    LOCAL_CLIENT_NODE               ovn-worker6
    LOCAL_CLIENT_POD                web-client-pod-76fws
    REMOTE_CLIENT_NODE              ovn-worker5
    REMOTE_CLIENT_POD               web-client-pod-wnbvx
    NODEPORT_CLUSTER_IPV4           10.96.204.9
    NODEPORT_ENDPOINT_IPV4          10.244.0.5
  Host backed:
    SERVER_HOST_IP                  172.18.0.8
    SERVER_HOST_NODE                ovn-worker6
    LOCAL_CLIENT_HOST_NODE          ovn-worker6
    LOCAL_CLIENT_HOST_POD           web-client-host-fz9b5
    REMOTE_CLIENT_HOST_NODE         ovn-worker5
    REMOTE_CLIENT_HOST_POD          web-client-host-p2rbn
    CLUSTERIP_HOST_SERVICE_IPV4     10.96.193.171
    NODEPORT_HOST_SVC_IPV4          10.96.74.153


FLOW 01: Typical Pod to Pod traffic (using cluster subnet)
----------------------------------------------------------

*** 1-a: Pod to Pod (Same Node) ***

kubectl exec -it web-client-pod-76fws -- curl "http://10.244.0.5:8080/"
SUCCESS

OVN-TRACE: BEGIN
ovn-trace indicates success from web-client-pod-fw8h4 to web-server-v4 - matched on output to "default_web-server-v4"
ovn-trace indicates success from web-server-v4 to web-client-pod-fw8h4 - matched on output to "default_web-client-pod-fw8h4"
ovs-appctl ofproto/trace indicates success from web-client-pod-fw8h4 to web-server-v4 - matched on output:13

Final flow:
ovs-appctl ofproto/trace indicates success from web-server-v4 to web-client-pod-fw8h4 - matched on output:14

Final flow:
OVN-TRACE: END (see ovn-traces/1a-pod2pod-same-node.txt for full detail)


*** 1-b: Pod to Pod (Different Node) ***

kubectl exec -it web-client-pod-wnbvx -- curl "http://10.244.0.5:8080/"
SUCCESS

OVN-TRACE: BEGIN
ovn-trace indicates success from web-client-pod-ccrvb to web-server-v4 - matched on output to "default_web-server-v4"
ovn-trace indicates success from web-server-v4 to web-client-pod-ccrvb - matched on output to "default_web-client-pod-ccrvb"
ovs-appctl ofproto/trace indicates success from web-client-pod-ccrvb to web-server-v4 - matched on -> output to kernel tunnel
ovs-appctl ofproto/trace indicates success from web-server-v4 to web-client-pod-ccrvb - matched on -> output to kernel tunnel
OVN-TRACE: END (see ovn-traces/1b-pod2pod-diff-node.txt for full detail)


FLOW 02: Pod -> Cluster IP Service traffic
------------------------------------------

*** 2-a: Pod -> Cluster IP Service traffic (Same Node) ***
kubectl exec -it web-client-pod-76fws -- curl "http://10.96.204.9:8080/"
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
* `ovnkube-trace` is run on every flow by default. To disable:
```
TEST_CASE=3 OVN_TRACE=false ./test.sh
```
<br>


*NOTE:* There are a couple of sub-FLOWs that are failing and not sure if they are suppose to work or not, so there are some test-case notes (in blue font) for those, for example:
> curl: (6) Could not resolve host: my-web-service-node-v4; Unknown error<br>
> Should this work?

## ovnkube-trace

`ovnkube-trace` is a tool in upstream OVN-Kubernetes to trace packet simulations
between points in ovn-kubernetes. `ovnkube-trace` is run by default on each sub-flow
and the output is piped to files in the `ovn-traces/` directory. Below is a list of
sample output files:
```
$ ls -al ovn-traces/
total 1072
drwxrwxr-x. 2 user user  4096 Apr 16 11:58 .
drwxrwxr-x. 5 user user   223 Apr 16 10:09 ..
-rw-rw-r--. 1 user user 84398 Apr 16 11:57 1a-pod2pod-same-node.txt
-rw-rw-r--. 1 user user 78030 Apr 16 11:57 1b-pod2pod-diff-node.txt
-rw-rw-r--. 1 user user 94706 Apr 16 11:57 2a-pod2clusterIPsvc-same-node.txt
-rw-rw-r--. 1 user user 88338 Apr 16 11:57 2b-pod2clusterIPsvc-diff-node.txt
-rw-rw-r--. 1 user user 94673 Apr 16 11:57 3a-pod2nodePortsvc-pod-backend-same-node.txt
-rw-rw-r--. 1 user user 88305 Apr 16 11:57 3b-pod2nodePortsvc-pod-backend-diff-node.txt
-rw-rw-r--. 1 user user 76891 Apr 16 11:57 3c-pod2nodePortsvc-host-backend-same-node.txt
-rw-rw-r--. 1 user user 73304 Apr 16 11:58 3d-pod2nodePortsvc-host-backend-diff-node.txt
-rw-rw-r--. 1 user user 23623 Apr 16 11:58 4a-pod2externalHost.txt
-rw-rw-r--. 1 user user 77620 Apr 16 11:58 5a-hostpod2clusterIPsvc-pod-backend-same-node.txt
-rw-rw-r--. 1 user user 78151 Apr 16 11:58 5b-hostpod2clusterIPsvc-pod-backend-diff-node.txt
-rw-rw-r--. 1 user user 77587 Apr 16 11:58 6a-hostpod2nodePortsvc-pod-backend-same-node.txt
-rw-rw-r--. 1 user user 78118 Apr 16 11:58 6b-hostpod2nodePortsvc-pod-backend-diff-node.txt
-rw-rw-r--. 1 user user 10841 Apr 16 11:58 7a-hostpod2clusterIPsvc-host-backend-same-node.txt
-rw-rw-r--. 1 user user  9903 Apr 16 11:58 7b-hostpod2clusterIPsvc-host-backend-diff-node.txt
-rw-rw-r--. 1 user user 10833 Apr 16 11:58 8a-hostpod2nodePortsvc-host-backend-same-node.txt
-rw-rw-r--. 1 user user  9896 Apr 16 11:58 8b-hostpod2nodePortsvc-host-backend-diff-node.txt
-rw-rw-r--. 1 user user    70 Apr 16 10:09 .gitignore
```

Examine these files to debug why a particular flow isn't working or to better understand
how a packet flows through OVN-Kubernetes for a particular flow.

*NOTE:* The `cleanup.sh` script does not remove these files and each subsequent run of
`test.sh` overwrites the previous test run.
