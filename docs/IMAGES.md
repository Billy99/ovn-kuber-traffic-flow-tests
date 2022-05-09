
# Container Images

This document describes the container images used by this repo and how to rebuild them.

## Table of Contents

- [http-server, iperf-server and client Images](#http-server-iperf-server-and-client-images)


## http-server, iperf-server and client Images

The `http-server`, the `iperf-server` and `client` pods are all using the same image,
which uses
[agnhost](https://pkg.go.dev/k8s.io/kubernetes/test/images/agnhost#section-readme)
as the base with `iperf3`, `iptables` and `tcpdump` packages pulled in. The
image has been built and pushed to `quay.io` for use by this repo.

```
quay.io/billy99/ft-base-image:0.9
```

The image has been built for multi-arch. The image must be built for each architecture
on a machine of that architecture. Then a manifest is created, pointing to each
architecture image.

From `x86` machine:

```
mkdir -p ~/src/; cd ~/src/
git clone https://github.com/billy99/ovn-kuber-traffic-flow-tests.git
cd ~/src/ovn-kuber-traffic-flow-tests/images/base-image/

sudo podman build -t quay.io/billy99/ft-base-image:0.9-x86_64 -f ./Containerfile .

sudo podman login quay.io
sudo podman push quay.io/billy99/ft-base-image:0.9-x86_64
```

From `arm` machine:

```
mkdir -p ~/src/; cd ~/src/
git clone https://github.com/billy99/ovn-kuber-traffic-flow-tests.git
cd ~/src/ovn-kuber-traffic-flow-tests/images/base-image/

sudo podman build -t quay.io/billy99/ft-base-image:0.9-aarch64 -f ./Containerfile .

sudo podman login quay.io
sudo podman push quay.io/billy99/ft-base-image:0.9-aarch64
```
Or from an x86 server:
```
sudo podman build --platform linux/arm64 -t quay.io/billy99/ft-base-image:0.9-aarch64 -f ./Containerfile .
```

From any machine:
```
sudo podman manifest create ft-base-image-0.9-list

sudo podman pull quay.io/billy99/ft-base-image:0.9-x86_64
sudo podman manifest add ft-base-image-0.9-list quay.io/billy99/ft-base-image:0.9-x86_64

sudo podman pull quay.io/billy99/ft-base-image:0.9-aarch64
sudo podman manifest add ft-base-image-0.9-list quay.io/billy99/ft-base-image:0.9-aarch64

sudo podman login quay.io
sudo podman manifest push ft-base-image-0.9-list quay.io/billy99/ft-base-image:0.9
```

## tools

This is not a private image. Just using https://github.com/nicolaka/netshoot as the tools image.
