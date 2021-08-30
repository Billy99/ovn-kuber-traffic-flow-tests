
# Container Images

This document describes the container images used by this repo and how to rebuild them.

## Table of Contents

- [http-server Image](#http-server-image)
- [Client and iperf-server Images](#client-and-iperf-server-images)


## http-server Image

The `http-server` pods currently use `registry.access.redhat.com/ubi8/python-38` image
to implement the http server.

## Client and iperf-server Images

The `client` pods and the `iperf-server` pods are using the same image, which uses
`docker.io/centos:8` as the base with `curl` and `iperf3` packages pulled in. The
image has been built and pushed to `quay.io` for use by this repo.

```
quay.io/billy99/ft-base-image:0.7
```

The image has been built for multi-arch. The image must be built for each architecture
on a machine of that architecture. Then a manifest is created, pointing to each
architecture image.

From `x86` machine:

```
mkdir -p ~/src/; cd ~/src/
git clone https://github.com/billy99/ovn-kuber-traffic-flow-tests.git
cd ~/src/ovn-kuber-traffic-flow-tests/images/base-image/

sudo podman build -t quay.io/billy99/ft-base-image:0.7-x86_64 -f ./Containerfile .

sudo podman login quay.io
sudo podman push quay.io/billy99/ft-base-image:0.7-x86_64
```

From `arm` machine:

```
mkdir -p ~/src/; cd ~/src/
git clone https://github.com/billy99/ovn-kuber-traffic-flow-tests.git
cd ~/src/ovn-kuber-traffic-flow-tests/images/base-image/

sudo podman build -t quay.io/billy99/ft-base-image:0.7-aarch64 -f ./Containerfile .

sudo podman login quay.io
sudo podman push quay.io/billy99/ft-base-image:0.7-aarch64
```

From any machine:
```
sudo podman manifest create ft-base-image-0.7-list

sudo podman pull quay.io/billy99/ft-base-image:0.7-x86_64
sudo podman manifest add ft-base-image-0.7-list quay.io/billy99/ft-base-image:0.7-x86_64

sudo podman pull quay.io/billy99/ft-base-image:0.7-aarch64
sudo podman manifest add ft-base-image-0.7-list quay.io/billy99/ft-base-image:0.7-aarch64

sudo podman login quay.io
sudo podman manifest push ft-base-image-0.7-list quay.io/billy99/ft-base-image:0.7
```