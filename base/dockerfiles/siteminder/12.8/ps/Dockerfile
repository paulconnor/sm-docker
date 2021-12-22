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
ENV PS_ZIP=ps-12.8-sp05-linux-x86-64.zip \
    ADMINUI_PRE_REQ_ZIP=adminui-pre-req-12.8-sp05-linux-x86-64.zip \
    ADMINUI_ZIP=adminui-12.8-sp05-linux-x86-64.zip \
    SDK_ZIP=smsdk-12.8-sp05-linux-x86-64.zip \
    BASE_DIR=/opt/CA/siteminder \
    INSTALL_TEMP=/tmp/sm_temp


#
# Creation of User, Directories and Installation of OS packages
# ----------------------------------------------------------------
RUN yum install -y which unzip rng-tools java-1.8.0-openjdk-devel ksh openldap-clients openssh-server xauth libnsl
RUN yum install -y sudo
RUN groupadd smuser && \
    useradd smuser -g smuser && \
    usermod -aG wheel smuser
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo
RUN mkdir -p ${BASE_DIR} && \
    chmod a+xr ${BASE_DIR} && \ 
    chown smuser:smuser ${BASE_DIR} 
RUN mkdir -p ${INSTALL_TEMP} && \
    chmod a+xr ${INSTALL_TEMP} && chown smuser:smuser ${INSTALL_TEMP} 


# Increase entropy
# ----------------
RUN mv /dev/random /dev/random.org && \
    ln -s /dev/urandom /dev/random

# Copy packages and scripts
# -------------------------
COPY --chown=smuser:smuser install/* ${INSTALL_TEMP}/
COPY --chown=smuser:smuser ca-ps-installer.properties ${INSTALL_TEMP}/
COPY --chown=smuser:smuser prerequisite-installer.properties ${INSTALL_TEMP}/
COPY --chown=smuser:smuser smwamui-installer.properties ${INSTALL_TEMP}/
COPY --chown=smuser:smuser sdk-installer.properties ${INSTALL_TEMP}/

USER smuser

# Install Policy Server
# -------------------------
RUN unzip ${INSTALL_TEMP}/${PS_ZIP} -d ${INSTALL_TEMP} && \
    chmod +x ${INSTALL_TEMP}/ca-ps-12.8-sp05-linux-x86-64.bin  && \
    ${INSTALL_TEMP}/ca-ps-12.8-sp05-linux-x86-64.bin -i silent -f ${INSTALL_TEMP}/ca-ps-installer.properties

RUN cp ${INSTALL_TEMP}/smreg /opt/CA/siteminder/bin 

RUN echo ". /opt/CA/siteminder/ca_ps_env.ksh" >> /home/smuser/.bash_profile

# Install Administrative Interface Prerequisites
# -----------------------------------------------
RUN unzip ${INSTALL_TEMP}/${ADMINUI_PRE_REQ_ZIP} -d ${INSTALL_TEMP} && \
    chmod +x ${INSTALL_TEMP}/adminui-pre-req-12.8-sp05-linux-x86-64.bin && \
    ${INSTALL_TEMP}/adminui-pre-req-12.8-sp05-linux-x86-64.bin -i silent -f ${INSTALL_TEMP}/prerequisite-installer.properties

# Install Administrative Interface
# -----------------------------------------------
RUN unzip ${INSTALL_TEMP}/${ADMINUI_ZIP} -d ${INSTALL_TEMP} && \
    chmod +x ${INSTALL_TEMP}/ca-adminui-12.8-sp05-linux-x86-64.bin && \
    ${INSTALL_TEMP}/ca-adminui-12.8-sp05-linux-x86-64.bin -i silent -f ${INSTALL_TEMP}/smwamui-installer.properties

# Install the SDK
# -----------------------------------------------
RUN unzip ${INSTALL_TEMP}/${SDK_ZIP} -d ${INSTALL_TEMP} && \
    chmod +x ${INSTALL_TEMP}/ca-sdk-12.8-sp05-linux-x86-64.bin && \
    ${INSTALL_TEMP}/ca-sdk-12.8-sp05-linux-x86-64.bin -i silent -f ${INSTALL_TEMP}/sdk-installer.properties

USER root 

RUN rm -fR ${INSTALL_TEMP} 

CMD ["/usr/sbin/init"]
