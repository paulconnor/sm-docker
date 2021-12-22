#!/bin/sh

./setup_ca.sh <<"EOF"
AU
Victoria
CA Technologies
Directory
Root CA for management UI node.js
__HOSTNAME_FQDN__
EOF


bash generate_cert_key.sh <<EOF
__HOSTNAME__
2
AU
Victoria
CA Technologies
Directory Management UI node.js
__HOSTNAME_FQDN__
EOF

