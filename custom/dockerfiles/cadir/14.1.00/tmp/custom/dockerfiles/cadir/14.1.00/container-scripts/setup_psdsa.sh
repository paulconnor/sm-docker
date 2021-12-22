#!/bin/bash
source /opt/CA/Directory/dxserver/install/.dxprofile 
#/opt/CA/Directory/dxserver/bin/dxserver start psdsa
/opt/CA/Directory/dxserver/bin/dxserver start userdir_cadir
/opt/CA/Directory/dxserver/bin/dxserver start ssopolicy_cadir
/opt/CA/Directory/dxserver/bin/dxserver start ssosession_cadir
#ldapadd -h dx -p 7777 -x -f /tmp/cadir_temp/setup.ldif
