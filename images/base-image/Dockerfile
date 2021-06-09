FROM docker.io/centos:8
USER root
RUN yum update -y && rm -rf /var/cache/yum
RUN yum install iperf3 curl -y && yum clean all
ENTRYPOINT trap : TERM INT; sleep infinity & wait # Listen for kill signals and exit quickly.

