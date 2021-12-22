# Pull base image
# ---------------
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
ENV AG_ZIP=ag-12.8-sp05-linux-x86-64.zip \
    BASE_DIR=/opt/CA/secure-proxy \
    ETC_DIR=/opt/etc \
    INSTALL_TEMP=/tmp/sp_temp 

#
# Creation of User, Directories and Installation of OS packages
# ----------------------------------------------------------------
RUN yum install -y which unzip rng-tools  java-1.8.0-openjdk-devel ksh openldap-clients openssh-server xauth
RUN yum install -y sudo
RUN groupadd smuser && \
    useradd smuser -g smuser && \
    usermod -aG wheel smuser
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo
RUN mkdir -p ${BASE_DIR} && \
    chmod a+xr ${BASE_DIR} && \ 
    chown smuser:smuser ${BASE_DIR} && \
    mkdir -p ${ETC_DIR} && \
    chmod a+xr ${ETC_DIR} && \ 
    chown smuser:smuser ${ETC_DIR} 

RUN mkdir -p ${INSTALL_TEMP} && \
    chmod a+xr ${INSTALL_TEMP} && chown smuser:smuser ${INSTALL_TEMP} 

USER root

# Increase entropy
# ----------------
RUN mv /dev/random /dev/random.org && \
    ln -s /dev/urandom /dev/random

# Copy packages and scripts
# -------------------------
COPY --chown=smuser:smuser install/* ${INSTALL_TEMP}/
COPY --chown=smuser:smuser ca-sps-installer.properties ${INSTALL_TEMP}/
COPY --chown=smuser:smuser ca-sps-config-installer.properties ${INSTALL_TEMP}/


USER smuser

# Install CA Access Gateway 
# --------------------------
RUN unzip ${INSTALL_TEMP}/${AG_ZIP} -d ${INSTALL_TEMP} && \
    chmod +x ${INSTALL_TEMP}/ca-proxy-12.8-sp05-linux-x86-64.bin && \
    ${INSTALL_TEMP}/ca-proxy-12.8-sp05-linux-x86-64.bin -i silent -f ${INSTALL_TEMP}/ca-sps-installer.properties 


RUN source /opt/CA/secure-proxy/default/ca_sps_env.sh && \
    /opt/CA/secure-proxy/default/ca-sps-config.sh -i silent -f ${INSTALL_TEMP}/ca-sps-config-installer.properties


USER root
RUN rm -fR ${INSTALL_TEMP}

CMD ["/usr/sbin/init"]
