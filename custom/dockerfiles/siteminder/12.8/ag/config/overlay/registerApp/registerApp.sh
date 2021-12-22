#!/bin/bash
cd /opt/CA/secure-proxy/registerApp
export SM_SMREGHOST_CLASSPATH=./:./java/smagentapi.jar:./java/smcrypto.jar:./java/bc-fips-1.0.1.jar

# Override some settings from helm setup
export RAPIDSSO_SMHOST_CONF=SmHost.conf

export DEBUG=false
export JAVA=/opt/CA/secure-proxy/default/install_config_info/jre/bin/java


RAPIDSSO_SECRET=$(${JAVA} -Dcom.ca.siteminder.sdk.agentapi.enableDebug=${DEBUG}  -Daddress=${RAPIDSSO_PS_ADDR}  -DfileName=${RAPIDSSO_SMHOST_CONF}  -DhostName=${RAPIDSSO_TRUSTED_HOST_NAME}  -DhostConfig=${RAPIDSSO_HOST_CONFIG}  -DuserName=${RAPIDSSO_ADMIN_USER}  -Dpassword=${RAPIDSSO_ADMIN_PASSWORD}  -cp $SM_SMREGHOST_CLASSPATH  RegisterApp)

echo "${RAPIDSSO_SECRET}"
