FROM pconnor/sm-ag:12.8.5
#
#
# Environment variables required for this build (do NOT change)
# -------------------------------------------------------------
#
ENV BASE_DIR=/opt/CA/secure-proxy 

USER root

# Copy packages and scripts
# -------------------------
RUN mkdir ${BASE_DIR}/registerApp
COPY --chown=smuser:smuser config/overlay/registerApp/*  ${BASE_DIR}/registerApp/

COPY --chown=root:sys config/init.d/agconfig /etc/init.d/
RUN chmod u+x /etc/init.d/agconfig && \
	/sbin/chkconfig agconfig on


RUN chown smuser:smuser ${BASE_DIR}/registerApp
RUN chmod +x ${BASE_DIR}/registerApp/*.sh


#COPY --chown=smuser:smuser config/overlay/server.conf /opt/CA/secure-proxy/default/proxy-engine/conf
COPY --chown=smuser:smuser config/overlay/proxyrules.xml /opt/CA/secure-proxy/default/proxy-engine/conf
COPY --chown=smuser:smuser config/overlay/SmHost.conf /opt/CA/secure-proxy/default/proxy-engine/conf/defaultagent/
COPY --chown=smuser:smuser config/overlay/WebAgent.conf /opt/CA/secure-proxy/default/proxy-engine/conf/defaultagent/
COPY --chown=smuser:smuser config/overlay/forms/* /opt/CA/secure-proxy/default/proxy-engine/examples/forms/

COPY --chown=smuser:smuser config/overlay/httpd-ssl.conf /opt/CA/secure-proxy/default/httpd/conf/extra/
COPY --chown=smuser:smuser config/overlay/httpd.conf /opt/CA/secure-proxy/default/httpd/conf/
COPY --chown=smuser:smuser config/overlay/server.conf /opt/CA/secure-proxy/default/proxy-engine/conf/




# Define default command to start bash.
CMD ["/sbin/init"]
