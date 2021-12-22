FROM pconnor/sm-ps:12.8.5

USER root

# Copy packages and scripts
# -------------------------

COPY --chown=root:sys config/init.d/psconfig /etc/init.d/
RUN chmod u+x /etc/init.d/psconfig && \
	/sbin/chkconfig psconfig on

USER smuser

COPY config/overlay/sm.registry /opt/CA/siteminder/registry/sm.registry
COPY config/overlay/keyStore.jks /opt/CA/siteminder/adminui/standalone/configuration/keyStore.jks


# Define default command to start bash.
USER root 
CMD ["/sbin/init"]
