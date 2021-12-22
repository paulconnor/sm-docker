FROM pconnor/dir:14.1.0

USER root

COPY config/init.d/dxconfig /etc/init.d/ 
RUN chmod +x /etc/init.d/dxconfig



# Copy Siteminder Policy Server configuration and database files
# ---------------------------------------------------------------
COPY --chown=dsa:etrdir config/siteminder/ps/config/schema/* /opt/CA/Directory/dxserver/config/schema/
COPY --chown=dsa:etrdir config/siteminder/ps/config/servers/* /opt/CA/Directory/dxserver/config/servers/
COPY --chown=dsa:etrdir config/siteminder/ps/config/limits/* /opt/CA/Directory/dxserver/config/limits/
COPY --chown=dsa:etrdir config/siteminder/ps/config/knowledge/* /opt/CA/Directory/dxserver/config/knowledge/
COPY --chown=dsa:etrdir config/siteminder/ps/config/settings/* /opt/CA/Directory/dxserver/config/settings/
COPY --chown=dsa:etrdir config/siteminder/ps/config/autostart/* /opt/CA/Directory/dxserver/config/autostart/
COPY --chown=dsa:etrdir config/siteminder/ps/data/* /opt/CA/Directory/dxserver/data/


USER root 
VOLUME [ "/sys/fs/cgroup" ]
CMD ["/sbin/init"]
