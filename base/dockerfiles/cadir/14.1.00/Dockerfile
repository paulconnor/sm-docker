FROM centos:7

ENV container docker

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;



#
#
# Environment variables required for this build (do NOT change)
# -------------------------------------------------------------
#
ENV CADIR_TGZ=cadir14.1.00_linux_x86_64_directory.tar.gz \
    BASE_DIR=/opt/CA/Directory \
    INSTALL_TEMP=/tmp/cadir_temp 


# Installation of OS packages
# ----------------------------------------------------------------
RUN yum install -y which unzip rng-tools java-1.8.0-openjdk-devel ksh python2 openldap-clients openssh-server && \
    ln -s /usr/bin/python2 /usr/local/bin/python

RUN groupadd etrdir && \
    useradd dsa -g etrdir

# Increase entropy
# ----------------
RUN mv /dev/random /dev/random.org && \
    ln -s /dev/urandom /dev/random

USER root

# Copy packages and scripts
# -------------------------
COPY install/* ${INSTALL_TEMP}/
COPY cadir_install_responses.properties ${INSTALL_TEMP}/


# Install CA Directory
# -------------------------
RUN tar zxvf ${INSTALL_TEMP}/${CADIR_TGZ} -C ${INSTALL_TEMP}

WORKDIR ${INSTALL_TEMP}/dxserver/install

RUN ./dxsetup.sh -responsefile ${INSTALL_TEMP}/cadir_install_responses.properties


VOLUME [ "/sys/fs/cgroup" ]

CMD ["/usr/sbin/init"]
