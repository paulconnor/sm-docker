#!/bin/sh
# CA Directory Management UI Setup Script 
# $Id: dxsetup.sh,v 1.263 2015/05/18 04:22:28 dmytry Exp $
################################################################################
#            CA Directory Managemet UI Installation Behaviour                  #
################################################################################
# dxmgmtuisetup.sh lets you select between Express Install and Custom Install  #
#                                                                              #
# Express Install:                                                             #
#                                                                              #
#   - The express setup will install DXserver using all the default locations  #
#     and settings.                                                            #
#                                                                              #
# Custom Install:                                                              #
#                                                                              #
#   - The custom setup takes you through our standard install, which lets the  #
#     user choose where and what they would like to install.                   #
#                                                                              #
# CA Directory Managemet UI Install:                                           #
#                                                                              #
#   - Install or upgrade CA Directory                                          #
#   - Select the installation location in which to install Management UI.      #
#   - Install Management UI in the specified location.                         #
#                                                                              #
################################################################################

#################################
# Setting Variables for install #
#################################
PROGNAME=DxMgmtUIsetup                    # Program Name
LICENSE_FILE=ca_license.txt               # The name of the license file
SHOW_LICENCE=0                            # Used to show End User License 
INSTUSER=root                             # must run install as this user 

DXSIZE=167                                # DXserver Size
UISIZE=5367
DOCSIZE=17                                # Size of documentation 

NODOCS=1                                  # Defining NoDocs switch variable
DEFANS=0                                  # Defining Default switch variable
DXGRIDSIZE=0                              # This is just so DXGRIDSIZE is initialised. 
SOURCEDIR=`pwd`                           # Declaring the Sourcedir variable
VERSION_FILE=osversion.txt                # file to use for OS version checking
RESPONSE_FILE=$SOURCEDIR/responsefile.txt # install defaults 
DAT=`date +%Y%m%d%H%M%S`                  # installation logging 
INSTALL_LOG_NAME=cadirmgmt_ui_install_        
INSTALL_LOG_NAME=${INSTALL_LOG_NAME}${DAT}
INSTALL_LOG_NAME=${INSTALL_LOG_NAME}.log
#NOUPGRADEBLD=2133
NOUPGRADEBLD=-1
RESTOREERROR=0

################################################################################
# mainline                                                                     #
################################################################################
main() 
{
    if [ -r $SOURCEDIR/dxprepare.shlib ]; then
        . $SOURCEDIR/dxprepare.shlib
    else
        echo "  Can't find library of dxsetup functions" 
        exit 1
    fi

    user_verify                           # whoami, must be $INSTUSER (default root)
    load_defaults                         # process response file
    check_sourcedir                       # for existance and readability
    set_operating_system                  # determine OS and set variables accordingly
    source_shared_file                    # source library files
    test_for_tar_files                 # tests for the install tar files 

    get_dxuser dxsetup                    # checks for existing DXUSER
    set_home_dirs                         # set the installed directories
    set_upgrade_variables                 # find out what is installed
    setup_write_response_file             # set up a responsefile
    find_previous_versions                # check if we need to upgrade
    initial_screens                       # License Agreement and Welcome screens.
    display_previous_versions

    check_defans                          # parameters for default install
    mgmtui_questions                      # questions for the Management UI install
    monitoring_questions                  # questions for the monitoring feature install
    scim_questions                        # questions for the SCIM Server install
    dxserver_questions mgmtui             # questions for the DXserver install
    capki_questions                       # questions for the CAPKI install
    dxagent_questions                 # questions for the DXagent install

    write_response_file                   # create a responsefile
    check_install_required                # check if anything being installed
    test_for_write_permissions            # check that dir owners (dsa, ingres) have write access 
    load_upgrade_defaults                 # handle response file upgrades
    run_dxserver_install                  # run the DXserver Install
    dxagent_check_cadir_version
    run_dxagent_install                   # installs DXagent 
    run_load_files
    run_mgmtui_install                    # installs management UI 
    run_monitoring_install                # installs monitoring feature
    run_scim_install                      # installs scim server
if [ $NONROOTUSER -eq 0 ]; then
    start_at_boot                         # sets up the reboot scripts
fi
    encrypt_config_data
    installation_complete                 # displays Installation Complete message
    relocate_log                          # copy log file to base directory
    show_readme                           # display readme at the end of install
}
################################################################################
################################################################################

get_ui_new_dir()
{
    PROD=$DXMGMTUIPROD
    PRODSIZE=$UISIZE
    INSTDIR=`dirname $DXHOME`/management-ui
    get_product_dir management-ui
    DXUIHOME=$INSTDIR
    export DXUIHOME
}

######################
# Load response file #
######################
load_defaults()
{
    if [ ! -f $RESPONSE_FILE ]; then
        echo | $LOG
        echo "  Unable to locate Response file ${RESPONSE_FILE}." | $LOG
        echo "  This sets all the default install options and is necessary" | $LOG
        echo "  for the install to continue. It must reside in the directory" | $LOG
        echo "  you are running dxsetup.sh from, or be referenced by the" | $LOG
        echo "  -responsefile parameter." | $LOG
        echo | $LOG
        echo "  Installation terminated." | $LOG
        exit 1
    fi

    # use a default of "y" for SETUID if installing from a custom response file     # to support backward compatibility (EEM for example default to port 389)
    if [ "$RSP" = "1" ]; then
        SETUID=y
    fi

    . $RESPONSE_FILE
    if [ ! "x$ADMINUSERPWD" = "x" ]; then
        # Check password policy compliance
        MSG=`$SOURCEDIR/dxppcheck -u admin -p "$ADMINUSERPWD" -f "$SOURCEDIR/passwdPolicy.txt"`
        RC=$?
        rm -f dxalarm.log
        if [ $RC -lt 200 ]; then
            if [ $RC != 0 ]; then
                echo "  Cannot check password quality, error code: $RC. Proceeding without password quality check." | $LOG
                echo | $LOG
            fi
        else
            echo $MSG | $LOG
            echo "Password quality rules for admin user:" | $LOG
            $SOURCEDIR/dxppcheck -l -f "$SOURCEDIR/passwdPolicy.txt" | $LOG
            echo | $LOG
            exit 1
        fi
    fi

    if [ -n "$CURDXGROUP" ]; then
           DXGROUP=$CURDXGROUP
           export DXGROUP
    fi
    
    # Now make values set in response file available to rest of install and check for sanity.
    if [ -z "$INSTUSER" -o \
         -z "$ETDIRHOME"  -o \
         -z "$DXSHELL" ]; then
        echo | $LOG
        echo "  The Response file ${RESPONSE_FILE} is corrupt." | $LOG
        echo "  Please ensure that all mandatory items have a value and none" | $LOG
        echo "  of these have been deleted." | $LOG
        echo | $LOG
        echo "  Installation terminated." | $LOG
        exit 1
    fi

    if [ -n "$DXHOME" ]; then
        PATHEND=`echo $DXHOME | awk 'BEGIN{FS="/"} {print $NF}'`
        if [ -z "$PATHEND" ]; then # catch trailing /
            PATHEND=`echo $DXHOME | sed 's/.$//' | awk 'BEGIN{FS="/"} {print $NF}'`
        fi
        if [ "$PATHEND" != "dxserver" ]; then
            echo | $LOG
            echo "  The Response file ${RESPONSE_FILE} " | $LOG
            echo "  or install user's env has DXHOME set to $DXHOME." | $LOG
            echo | $LOG
            echo "  This pathname must end with a /dxserver directory." | $LOG
            echo | $LOG
            echo "  Installation terminated." | $LOG
            exit 1
        fi
    fi

    #13682 new checks for all responsefile parameters
    for TESTDIR in $BACKUPLOC $DXHOME $CAPKILOC; do
        if [ -n "$TESTDIR" ]; then
            echo $TESTDIR | cut -c 1-1 | grep -v "[a-zA-Z0-9/._]" > /dev/null
            if [ $? -eq 0 ]; then
                echo | $LOG
                echo "  Your response file contains an item with the value $TESTDIR" 
                echo "  $TESTDIR contains an invalid character." | $LOG
                echo | $LOG
                echo "  Installation terminated." | $LOG
                exit 1
            fi
            
             echo $TESTDIR | cut -c 1-1 | grep "/" > /dev/null
            if [ $? -ne 0 ]; then
                echo | $LOG
                echo "  Your response file contains an item with the value $TESTDIR" 
                echo "  This item must be a full path." | $LOG
                echo | $LOG
                echo "  Installation terminated." | $LOG
                exit 1
            fi
            #need to check to see if user is trying to install to / 'or /dxserver
            if [ "`dirname $TESTDIR`" = "/" ] || [ "`dirname $TESTDIR`" = "/root" ]; then
                echo | $LOG
                echo "  Response file value $TESTDIR must not be installed to the '/' directory, and " | $LOG
                echo "  should be a few levels down from the '/' directory."     | $LOG
                echo "  Please re-enter."                                         | $LOG
                exit 1
            fi
        fi
    done
    for TESTDIR in $BACKUPLOC; do
        check_writeable $TESTDIR
        if [ $WRITEABLE = "n" ]; then
            echo 
            echo " The directory $TESTDIR has insufficient permissions " | $LOG
            echo " Please ensure that this directory has the right permissions " | $LOG
            echo " before continuing "                                             | $LOG
            exit 1
        fi
    done
    
    for TESTVAL in $INSTALLDX $INSTALLDOC $INSTALLDXAGENT $SETUID $BACKUPBIN $RESTARTDSAS; do
        if [ -n "$TESTVAL" ]; then
            case "${TESTVAL}" in 
                [Yy]*)
                ;;
                [Nn]*)
                ;;
                *)
                echo | $LOG
                echo " One of the items in your response file contains the value $TESTVAL" | $LOG
                echo "This needs to be either a y (yes) or n (no) response" | $LOG
                echo | $LOG
                echo "  Installation terminated." | $LOG
                exit 1
                ;;
            esac
        fi
    done
    if [ -n "$INSTALLDX" ]; then
        # we are running a responsefile generated by dxsetup
        DEFANS=1
    fi

}

write_response_file()
{
    if [ -z "$WRITE_RESPONSE_FILE" ]; then
        return
    fi

    if [ "$DXUID" = "0" ]; then 
        DXUID="" 
    fi
    if [ "$DXGID" = "0" ]; then 
        DXGID="" 
    fi

    rm -f $WRITE_RESPONSE_FILE > /dev/null 2>&1

    if [ `uname` = "SunOS" -a ! "x$LEGACY_SETUID" = "xy" ]; then
        PFSHELL=`echo $DXSHELL |grep "\/pf"`
        if [ $? -ne 0 ]; then
            SHELL=`basename $DXSHELL`
            if [ "$SHELL" = "sh" -o "$SHELL" = "csh" ];then
                DXSHELL_NEW=/bin/pf$SHELL
            elif [ "$SHELL" = "ksh" ];then
                DXSHELL_NEW=/usr/bin/pfksh
            else
                DXSHELL_NEW=/bin/pfsh
            fi
            echo "Changing $DXUSER default login shell $DXSHELL to $DXSHELL_NEW because 'net_privaddr' approach is used to allow listening on ports <= 1024" | $LOG
            DXSHELL=$DXSHELL_NEW
        fi
    fi

cat << EOF >> $WRITE_RESPONSE_FILE
# ==============================
#   $PRODNAME Response File
# ==============================
# $DXVERSION
# `date`

# User parameters
INSTUSER=$INSTUSER
DXUSER=$DXUSER
DXSHELL=$DXSHELL
DXUID=$DXUID
DXGROUP=$DXGROUP
DXGID=$DXGID

# Install parameters
INSTALLDX=$INSTALLDX
INSTALLDOC=$INSTALLDOC
INSTALLDXAGENT=$INSTALLDXAGENT
SETUID=$SETUID
LEGACY_SETUID=$LEGACY_SETUID
DXMASTERKEYPASS=$DXMASTERKEYPASS

# Location parameters
ETDIRHOME=$ETDIRHOME
DXHOME=$DXHOME
CAPKILOC=$CAPKILOC

# DXagent parameters
DXAGENTCLIENT=$DXAGENTCLIENT
DXAGENTPORT=$DXAGENTPORT
DXAGENTPASS=$DXAGENTPASS

# Upgrade parameters
BACKUPBIN=$BACKUPBIN
BACKUPLOC=$BACKUPLOC
RESTARTDSAS=$RESTARTDSAS

# Management UI
INSTALLUI=$INSTALLUI
UIWEBPORT=$UIWEBPORT
USEOWNWEBCERT=$USEOWNWEBCERT
UIWEBCERTPATH=$UIWEBCERTPATH
UIWEBPRIVKEYPATH=$UIWEBPRIVKEYPATH
UIWEBCACERTPATH=$UIWEBCACERTPATH
UIDSAPORTLOCAL=$UIDSAPORTLOCAL
ADMINUSERPWD=$ADMINUSERPWD

# Monitoring
UIDSAMONPORTLOCAL=$UIDSAMONPORTLOCAL
NODEJSHOSTNAME=$NODEJSHOSTNAME

#SCIM
SCIMPORT=$SCIMPORT
SCIMCERTPATH=$SCIMCERTPATH
SCIMPRIVKEYPATH=$SCIMPRIVKEYPATH

EOF

    # we need to create the user to allow the rest of the install questions,
    # but we don't want to keep them because then we can't do a real install.
    if [ -n "$DXUSER_CREATED" ]; then
        dxuserdel $DXUSER
    fi

    chmod 400 $WRITE_RESPONSE_FILE

    echo | $LOG
    echo "============================ RESPONSE FILE COMPLETE ===========================" | $LOG
    echo | $LOG
    echo "  The Response File at $WRITE_RESPONSE_FILE is complete."  | $LOG
    echo "  To install $PRODNAME using this Response File, run:"  | $LOG
    echo "    ./dxmgmtuisetup.sh -responsefile $WRITE_RESPONSE_FILE"       | $LOG
    echo | $LOG
    
    exit 0
}

check_install_required()
{
    MSG=1
    if [ "$INSTALLUI"  = "y" -o $SKIPUI -eq 1 ]; then MSG=0
    elif [ "$INSTALLDX"  = "y" -o $SKIPDX -eq 1 ]; then MSG=0
    elif [ "$INSTALLDXAGENT"  = "y" ]; then MSG=0
    fi
    if [ $MSG -eq 1 ]; then
        echo | $LOG
        echo | $LOG

        echo "  ***********************************************************************" | $LOG
        echo "    You have chosen to install nothing. If you want to install a "         | $LOG
        echo "    component please answer [y]es when prompted during the install."       | $LOG
        echo "  ***********************************************************************" | $LOG
        echo | $LOG
        echo "  Installation terminated." | $LOG
        remove_temp_files
        exit 1
    fi

    export DXUSER_CREATED DXHOME DXWEBHOME 
}

####################
# DX Management UI #
####################

scim_questions()
{
    echo | $LOG
    echo "============================ SCIM SERVER QUESTIONS ============================" | $LOG

    if [ $SKIPUI -eq 1 ]; then  # we already have this version
        return
    elif [ "$UPGRADEUI" = "1" ]; then
        if [ $UICUR_MAJOR -eq 12 ]; then
            NO_SCIM="y"
        fi
        if [ $DEFANS -eq 1 ]; then
            return
        fi
    fi
    if [ "$INSTALLUI" = "y" ]; then
        if [ "$UPGRADEUI" = "1" -a "x$NO_SCIM" = "x" ]; then
            # No more prompts: upgrade from version > 12.*
            return
        fi
        if [ $DEFANS -eq 0 -o -z "$SCIMPORT" ]; then
            QUESTION="  Enter the port for the SCIM Server"
            DEFAULT=3100
            get_response port
            SCIMPORT=$RETURN
        fi
        if [ "$USEOWNWEBCERT" = "y" ]; then
            if [ $DEFANS -eq 0 -o -z "$UIWEBCACERTPATH" ]; then
                while [ "x$UIWEBCACERTPATH" = "x" ]; do
                    QUESTION="  Enter path to the CA certificate pem file"
                    DEFAULT=
                    get_response path
                    if [ "x$RETURN" = "x" ]; then continue; fi
                        if [ -r $RETURN ]; then
                            openssl x509 -in "$RETURN" -text -noout > /dev/null 2>&1
                            if [ $? -eq 0 ]; then
                                openssl verify -CAfile "$RETURN" "$UIWEBCERTPATH" > /dev/null 2>&1
                                if [ $? -eq 0 ]; then
                                    UIWEBCACERTPATH=$RETURN
                                else
                                    echo "    $UIWEBCERTPATH is not issued by CA with '$RETURN' CA certificate"
                                fi
                            else
                                    echo "    $RETURN is not a valid certificate"
                            fi
                        else
                            echo "    cannot access $RETURN"
                        fi
                done
            fi
            while [ "x$SCIMCERTPATH" = "x" ]; do
                while [ "x$SCIMCERTPATH" = "x" ]; do
                    QUESTION="  Enter path to the client certificate pem file"
                    DEFAULT=
                    get_response path
                    if [ "x$RETURN" = "x" ]; then continue; fi
                    if [ -r $RETURN ]; then
                        openssl x509 -in "$RETURN" -text -noout > /dev/null 2>&1
                        if [ $? -eq 0 ]; then
                            openssl verify -CAfile "$UIWEBCACERTPATH" "$RETURN" > /dev/null 2>&1
                            if [ $? -eq 0 ]; then
                                MOD1=`openssl x509 -noout -modulus -in "$RETURN"` > /dev/null 2>&1
                                if [ $? -eq 0 ]; then
                                    SCIMCERTPATH=$RETURN
                                else
                                    echo "    cannot retrieve modulus from $RETURN"
                                fi
                            else
                                echo "    $RETURN is not issued by CA with '$UIWEBCACERTPATH' CA certificate"
                            fi
                        else
                            echo "    $RETURN is not a valid certificate"
                        fi
                    else
                        echo "    cannot access $RETURN"
                    fi
                done
                while [ "x$SCIMPRIVKEYPATH" = "x" ]; do
                    QUESTION="  Enter path to the client private key pem file"
                    DEFAULT=
                    get_response path
                    if [ "x$RETURN" = "x" ]; then continue; fi
                    if [ -r $RETURN ]; then
                        openssl rsa -in "$RETURN" -check > /dev/null 2>&1
                        if [ $? -eq 0 ]; then
                            MOD2=`openssl rsa -noout -modulus -in "$RETURN"` > /dev/null 2>&1
                            if [ $? -eq 0 ]; then
                                SCIMPRIVKEYPATH=$RETURN
                            else
                                echo "    cannot retrieve modulus from $RETURN"
                            fi
                        else
                            echo "    $RETURN is not a valid private key"
                        fi
                    else
                        echo "    cannot access $RETURN"
                    fi
                done
                if [ "$MOD1" != "$MOD2" ]; then
                        SCIMCERTPATH=""
                        SCIMPRIVKEYPATH=""
                        echo "The certificate and the private key do not match"
                fi
            done
        else
            SCIMCERTPATH=$DXUIHOME/out/scimclientcert.pem
            SCIMPRIVKEYPATH=$DXUIHOME/out/scimclientcert.key
            UIWEBCACERTPATH=$DXUIHOME/CA/certs/ca.pem
        fi
        if [ -z "$SCIMPORT" ]; then
            SCIMPORT=3100
        fi
    fi
}

run_scim_install()
{
    if [ "$INSTALLUI" = "n" ]; then
        return
    fi

    echo | $LOG
    echo "=========================== SCIM SERVER INSTALLATION ==========================" | $LOG
    echo | $LOG
    
    DIRECTORYDIR=`dirname $DXHOME`
    cd $DIRECTORYDIR/management-ui
    if [ "x$DXUIHOME" = "x" ]; then
        DXUIHOME=`pwd`
    fi

    if [ "$UPGRADEUI" = "1" ] && [ "x$NO_SCIM" = "x" ]; then
        # This is upgrade: restore original config-scim.js and certs
        mv -f $SAVE_CONFIG_SCIM_JS $DIRECTORYDIR/management-ui/config-scim.js
#       mv -f $SAVE_CERTS_KEYS/* $DIRECTORYDIR/management-ui/api-server/certs
#       mv -f $SAVE_CA_CERTS/* $DIRECTORYDIR/management-ui
#       rm -rf $SAVE_CONFIG_JS $SAVE_CERTS_KEYS $SAVE_CA_CERTS
        chown -R $DXUSER $DXUIHOME
        echo "  Starting SCIM server..."  | $LOG
        echo
        if [ $NONROOTUSER -eq 0 ]; then
            su - $DXUSER -c "${DXUIHOME}/dxscimserver start"  >> $INSTALL_LOG 2>&1
        else
            /bin/sh -c "$DXSRCSH;${DXUIHOME}/dxscimserver start"  >> $INSTALL_LOG 2>&1
        fi
        return
    fi

    if [ "$USEOWNWEBCERT" = "y" ]; then
        cp $SCIMCERTPATH $DXUIHOME/api-server/certs/
        cp $SCIMPRIVKEYPATH $DXUIHOME/api-server/certs/
        cp $UIWEBCACERTPATH $DXUIHOME/CA/certs
        server_cert=`basename $UIWEBCACERTPATH`
        CACERT_CONFIG=`cat $DXUIHOME/config-default.js|grep -A 1000 "module.exports.caCertificateFile"|grep -m 1 -B 1000 "};"`
        CACERT_CONFIG=`echo "$CACERT_CONFIG"|sed -e "s|'CA'|'api-server'|"`
        CACERT_CONFIG=`echo "$CACERT_CONFIG"|sed -e "s|'ca.pem'|'$server_cert'|"`
        echo >> $DXUIHOME/config.js
        echo "$SSL_CONFIG" >> $DXUIHOME/config.js
        echo >> $DXUIHOME/config.js
        echo >> $DXUIHOME/config-scim.js
        echo "$SSL_CONFIG" >> $DXUIHOME/config-scim.js
        echo >> $DXUIHOME/config-scim.js
        SSL_CONFIG=`cat $DIRECTORYDIR/management-ui/config.js|grep -A 1000 "module.exports.sslConfig"|grep -m 1 -B 1000 "};"`
        echo "  Modifying config-scim.js ..."  | $LOG
        echo
        if [ ! "x$SSL_CONFIG" = "x" ]; then
            echo >> $DXUIHOME/config-scim.js
            echo "$SSL_CONFIG" >> $DXUIHOME/config-scim.js
            echo >> $DXUIHOME/config-scim.js
        fi
    else
        echo "  Generating client certificates for SCIM server..."  | $LOG
        echo
        HOSTNAME_FQDN=`hostname -f`
        if [ $? -ne 0 ] || [ -z "$HOSTNAME_FQDN" ]; then
            echo "Unable to obtain hostname FQDN. Installation aborted."
            exit 1
        fi
        cp $SOURCEDIR/generate_cert_key.sh $DXUIHOME
        cp $SOURCEDIR/openssl-ca/openssl-ca.cnf $DXUIHOME
        cp $SOURCEDIR/openssl-ca/openssl-req.cnf $DXUIHOME
        cat << EOF > $DXUIHOME/gen_client_cert.sh
#!/bin/sh
bash generate_cert_key.sh <<EOFILE
scimclientcert
1
C@D1r3ct0ry
AU
Victoria
CA Technologies
CA Directory
SCIM on $HOSTNAME_FQDN
EOFILE
EOF

        chmod a+x $DXUIHOME/gen_client_cert.sh
        chown -R $DXUSER $DXUIHOME
            if [ $NONROOTUSER -eq 0 ]; then
                su - $DXUSER -c "cd $DXUIHOME; ./gen_client_cert.sh; cp $DXUIHOME/out/scimclientcert.pem $DXUIHOME/out/scimclientcert.key $DXUIHOME/api-server/certs" >> $INSTALL_LOG 2>&1
            else
                /bin/sh -c "$DXSRCSH;cd $DXUIHOME; ./gen_client_cert.sh; cp $DXUIHOME/out/scimclientcert.pem $DXUIHOME/out/scimclientcert.key $DXUIHOME/api-server/certs" >> $INSTALL_LOG 2>&1
            fi
        rm $DXUIHOME/generate_cert_key.sh $DXUIHOME/gen_client_cert.sh $DXUIHOME/openssl-ca.cnf $DXUIHOME/openssl-req.cnf
    fi
    if [ $SCIMPORT -ne 3100 ]; then
        echo >> $DXUIHOME/config-scim.js
        echo "module.exports.port = $SCIMPORT;" >> $DXUIHOME/config-scim.js
        echo >> $DXUIHOME/config-scim.js
    fi

    SCIMUSERPWD=`openssl rand -base64 32`
    if [ $NONROOTUSER -eq 0 ]; then
        SCIMUSERPWDENC=`su - $DXUSER -c "$DXHOME/bin/dxpassword -P CADIR $SCIMUSERPWD"`  >> $INSTALL_LOG 2>&1
    else
        SCIMUSERPWDENC=`/bin/sh -c "$DXSRCSH;$DXHOME/bin/dxpassword -P CADIR $SCIMUSERPWD"`  >> $INSTALL_LOG 2>&1
    fi

    #Add scim user
    #dump embedded DSA
    LOCAL_DSA_NAME=$(hostname)-management-ui
    echo "  Stopping $LOCAL_DSA_NAME DSA ..."  | $LOG
    echo
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "dxserver stop $LOCAL_DSA_NAME;dxdumpdb -f $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    else
        /bin/sh -c "$DXSRCSH;dxserver stop $LOCAL_DSA_NAME;dxdumpdb -f $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    fi

    echo "  Adding SCIM user to $LOCAL_DSA_NAME DSA ..."  | $LOG
    echo
    #add SCIM user to ldif
    echo >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "dn: cn=scim,ou=users,o=management-ui" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "objectClass: top" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "objectClass: person" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "cn: scim" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "sn: scim" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "userPassword: $SCIMUSERPWD" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    chown $DXUSER $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    #re-populate embedded DSA and start it
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "dxloaddb $LOCAL_DSA_NAME $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif;dxserver start $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    else
        /bin/sh -c "$DXSRCSH;dxloaddb $LOCAL_DSA_NAME $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif;dxserver start $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    fi
    rm -f $LOCAL_DSA_NAME.ldif

    # get module.exports.mgmtServerConnection setting from config-scim-default.js
    EXTERNAL_MONITOR=`cat $DIRECTORYDIR/management-ui/config-scim-default.js |grep -A 1000 "module.exports.mgmtServerConnection"|grep -m 1 -B 1000 "};"`
    # replace monitor username and password in module.exports.mgmtServerConnection
    EXTERNAL_MONITOR=`echo "$EXTERNAL_MONITOR"|sed -e "s|password: 'changeme'|password: '$SCIMUSERPWDENC'|"`
    if [ "$USEOWNWEBCERT" = "y" ]; then
    # change rejectUnauthorized to 'true' in module.exports.mgmtServerConnection in case of using customer's certificates
        EXTERNAL_MONITOR=`echo "$EXTERNAL_MONITOR"|sed -e "s|rejectUnauthorized: 'false'|rejectUnauthorized: 'true'|"`
    fi
    cat $DIRECTORYDIR/management-ui/config.js |grep 'module.exports.port' > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        UIWEBPORT=`cat $DIRECTORYDIR/management-ui/config.js |grep 'module.exports.port'|awk -F"=" '{print $2}'|awk -F";" '{print $1}'`
        EXTERNAL_MONITOR=`echo "$EXTERNAL_MONITOR"|sed -e "s|port: 3000|port: $UIWEBPORT|"`
    fi
    # put module.exports.externalMonitor in the config.js
    echo "$EXTERNAL_MONITOR" >> $DIRECTORYDIR/management-ui/config-scim.js

    chown -R $DXUSER $DXUIHOME | $LOG
    chgrp -R $DXGROUP $DXUIHOME | $LOG

    if [ $NONROOTUSER -eq 0 ]; then
        echo "  Starting $DXMGMTUIPROD node.js server..."  | $LOG
        echo
        su - $DXUSER -c "${DXUIHOME}/dxmgmtuiserver start"  >> $INSTALL_LOG 2>&1

        echo "  Starting SCIM server..."  | $LOG
        echo
        su - $DXUSER -c "${DXUIHOME}/dxscimserver start"  >> $INSTALL_LOG 2>&1
    else
        echo "  Starting SCIM server..."  | $LOG
        echo

        echo "  Starting $DXMGMTUIPROD node.js server..."  | $LOG
        echo
        /bin/sh -c "$DXSRCSH;${DXUIHOME}/dxmgmtuiserver start"  >> $INSTALL_LOG 2>&1
        
        echo "  Starting SCIM server..."  | $LOG
        echo
        /bin/sh -c "$DXSRCSH;${DXUIHOME}/dxscimserver start"  >> $INSTALL_LOG 2>&1
    fi
}

monitoring_questions()
{
    echo | $LOG
    echo "========================== DSA MONITORING QUESTIONS ===========================" | $LOG

    if [ $SKIPUI -eq 1 ]; then  # we already have this version
        return
    elif [ "$UPGRADEUI" = "1" ]; then
        if [ $UICUR_MAJOR -eq 12 ]; then
            NO_MONITOR_DSA="y"
        fi
        if [ $DEFANS -eq 1 ]; then
            return
        fi
    fi
    if [ "$INSTALLUI" = "y" ]; then
        if [ "$UPGRADEUI" = "1" -a "x$NO_MONITOR_DSA" = "x" ]; then
            # No more prompts: upgrade from version > 12.*
            return
        fi
        if [ $DEFANS -eq 0 -o -z "$UIDSAMONPORTLOCAL" ]; then
            QUESTION="  Enter the port for the Monitoring Data DSA"
            DEFAULT=11389
            get_response port
            UIDSAMONPORTLOCAL=$RETURN
        fi
    fi
}

run_monitoring_install()
{
    if [ "$INSTALLUI" = "n" ]; then
        return
    fi
    if [ "$UPGRADEUI" = "1" -a "x$NO_MONITOR_DSA" = "x" ]; then
        return
    fi

    echo | $LOG
    echo "===================== DSA MONITORING FEATURE INSTALLATION =====================" | $LOG
    echo | $LOG
    
    DIRECTORYDIR=`dirname $DXHOME`
    cd $DIRECTORYDIR/management-ui
    if [ "x$DXUIHOME" = "x" ]; then
        DXUIHOME=`pwd`
    fi
    if [ "x$UIWEBCERTPATH" = "x" ]; then
        # get web certificate and priv key names
        SSL_CONFIG=`cat $DIRECTORYDIR/management-ui/config.js|grep -A 1000 "module.exports.sslConfig"|grep -m 1 -B 1000 "};"`
        UIWEBCERTPATH=`echo "$SSL_CONFIG" |awk -F"cert: " '{print $2}'|awk -F","  '{print $1}'|awk -F"'"  '{print $2}'|sed '/^\s*$/d'`
    fi
    echo "  Modifying config.js ..."  | $LOG
    echo

    if [ "x$HOSTNAME_FQDN" = "x" ]; then
        HOSTNAME_FQDN=`hostname -f`
    fi


    MONITORUSERPWD=`openssl rand -base64 32`
    if [ $NONROOTUSER -eq 0 ]; then
        MONITORUSERPWDENC=`su - $DXUSER -c "$DXHOME/bin/dxpassword -P CADIR $MONITORUSERPWD"`  >> $INSTALL_LOG 2>&1
    else
        MONITORUSERPWDENC=`/bin/sh -c "$DXSRCSH;$DXHOME/bin/dxpassword -P CADIR $MONITORUSERPWD"`  >> $INSTALL_LOG 2>&1
    fi

    # get module.exports.externalMonitor setting from config-default.js
    EXTERNAL_MONITOR=`cat $DIRECTORYDIR/management-ui/config-default.js |grep -A 1000 "module.exports.externalMonitor"|grep -m 1 -B 1000 "};"`
    # replace monitor username, password and hostname in module.exports.externalMonitor
    EXTERNAL_MONITOR=`echo "$EXTERNAL_MONITOR"|sed -e "s|username: 'admin'|username: 'monitor'|"`
    EXTERNAL_MONITOR=`echo "$EXTERNAL_MONITOR"|sed -e "s|password: 'admin'|password: '$MONITORUSERPWDENC'|"`
    EXTERNAL_MONITOR=`echo "$EXTERNAL_MONITOR"|sed -e "s|hostname: require(\"os\").hostname()|hostname: '$HOSTNAME_FQDN'|"`
    # put module.exports.externalMonitor in the config.js
    echo "$EXTERNAL_MONITOR" >> $DIRECTORYDIR/management-ui/config.js

    if [ "x$UIWEBPORT" = "x" ]; then
        UIWEBPORT=`cat $DIRECTORYDIR/management-ui/config.js |grep "module.exports.port"|tail -1|tr -d ' '|awk -F= '{print $2}'|tr -d ';'`
    fi
    
    #Add monitoring user
    #dump embedded DSA
    LOCAL_DSA_NAME=$(hostname)-management-ui
    LOCAL_MONITORING_DSA_NAME=$(hostname)-monitoring-management-ui
    echo "  Stopping $LOCAL_DSA_NAME DSA ..."  | $LOG
    echo
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "dxserver stop $LOCAL_DSA_NAME;dxdumpdb -f $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    else
        /bin/sh -c "$DXSRCSH;dxserver stop $LOCAL_DSA_NAME;dxdumpdb -f $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    fi

    echo "  Adding monitor user to $LOCAL_DSA_NAME DSA ..."  | $LOG
    echo
    echo >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "dn: cn=monitor,ou=users,o=management-ui" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "objectClass: top" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "objectClass: person" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "cn: monitor" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "sn: monitor" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo "userPassword: $MONITORUSERPWD" >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    echo >> $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    chown $DXUSER $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "dxloaddb $LOCAL_DSA_NAME $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif"  >> $INSTALL_LOG 2>&1
    else
        /bin/sh -c "$DXSRCSH;dxloaddb $LOCAL_DSA_NAME $DIRECTORYDIR/management-ui/$LOCAL_DSA_NAME.ldif"  >> $INSTALL_LOG 2>&1
    fi
    rm -f $LOCAL_DSA_NAME.ldif
    
    # create monitoring DSA
    echo "  Creating embedded monitoring DSA $LOCAL_MONITORING_DSA_NAME ..."  | $LOG
    echo
    # change monitoring DSA config
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "dxnewdsa -s 5000 $LOCAL_MONITORING_DSA_NAME $UIDSAMONPORTLOCAL ou=messages,o=management-ui; dxserver stop $LOCAL_MONITORING_DSA_NAME;dxserver install $LOCAL_MONITORING_DSA_NAME"  >> $INSTALL_LOG 2>&1
    else
        /bin/sh -c "$DXSRCSH;dxnewdsa -s 5000 $LOCAL_MONITORING_DSA_NAME $UIDSAMONPORTLOCAL ou=messages,o=management-ui; dxserver stop $LOCAL_MONITORING_DSA_NAME;dxserver install $LOCAL_MONITORING_DSA_NAME"  >> $INSTALL_LOG 2>&1
    fi

    echo "  Modifying Management UI embedded DSAs configuration ..."  | $LOG
    echo
    DSA_SERVER_DXI=`cat $DXHOME/config/servers/$LOCAL_MONITORING_DSA_NAME.dxi`
    DSA_SERVER_DXI=`echo "$DSA_SERVER_DXI"|sed -e "s|source \"\.\.\/schema\/default.dxg\";|source \"\.\.\/schema\/x500.dxc\";\nsource \"\.\.\/schema\/dxserver.dxc\";\nsource \"\.\.\/schema\/management-ui.dxc\";|g"`
    DSA_SERVER_DXI=`echo "$DSA_SERVER_DXI"|sed -e "s|source \"\.\.\/access\/default.dxc\";|source \"\.\.\/access\/management-ui-access.dxc\";|g"`
    DSA_SERVER_DXI=`echo "$DSA_SERVER_DXI"|sed -e "s|clear dsas;|clear dsas;\nsource \"../knowledge/$LOCAL_DSA_NAME.dxc\";|g"`
    echo "$DSA_SERVER_DXI" > $DXHOME/config/servers/$LOCAL_MONITORING_DSA_NAME.dxi
    echo "set disable-client-binds = true;" >> $DXHOME/config/servers/$LOCAL_MONITORING_DSA_NAME.dxi

    echo "set external-monitor \"externalMonitor\" = " >> $DXHOME/config/servers/$LOCAL_MONITORING_DSA_NAME.dxi
    echo "{" >> $DXHOME/config/servers/$LOCAL_MONITORING_DSA_NAME.dxi
    echo "   endpoint       = \"https://$HOSTNAME_FQDN:$UIWEBPORT/embeddedMessageDsa\"" >> $DXHOME/config/servers/$LOCAL_MONITORING_DSA_NAME.dxi
    echo "   monitor-events = cache" >> $DXHOME/config/servers/$LOCAL_MONITORING_DSA_NAME.dxi
    echo "   credentials    = username monitor password \"$MONITORUSERPWD\"" >> $DXHOME/config/servers/$LOCAL_MONITORING_DSA_NAME.dxi
    echo "   push-interval  = 300" >> $DXHOME/config/servers/$LOCAL_MONITORING_DSA_NAME.dxi
    echo "};" >> $DXHOME/config/servers/$LOCAL_MONITORING_DSA_NAME.dxi
    
    DSA_KNOWLEDGE_DXC=`cat $DXHOME/config/knowledge/$LOCAL_MONITORING_DSA_NAME.dxc`
    DSA_KNOWLEDGE_DXC=`echo "$DSA_KNOWLEDGE_DXC"|sed -e "s|};|\n    dsa-flags = multi-write, no-service-while-recovering\n};|g"`
    DSA_KNOWLEDGE_DXC=`echo "$DSA_KNOWLEDGE_DXC"|sed -e "s|};|\n    trust-flags = trust-conveyed-originator, allow-check-password\n};|g"`
    echo "$DSA_KNOWLEDGE_DXC" > $DXHOME/config/knowledge/$LOCAL_MONITORING_DSA_NAME.dxc

    # change management DSA config
    DSA_SERVER_DXI=`cat $DXHOME/config/servers/$LOCAL_DSA_NAME.dxi`
    DSA_SERVER_DXI=`echo "$DSA_SERVER_DXI"|sed -e "s|clear dsas;|clear dsas;\nsource \"../knowledge/$LOCAL_MONITORING_DSA_NAME.dxc\";|g"`
    echo "$DSA_SERVER_DXI" > $DXHOME/config/servers/$LOCAL_DSA_NAME.dxi

    DSA_KNOWLEDGE_DXC=`cat $DXHOME/config/knowledge/$LOCAL_DSA_NAME.dxc`
    DSA_KNOWLEDGE_DXC=`echo "$DSA_KNOWLEDGE_DXC"|sed -e "s|};|\n    trust-flags = trust-conveyed-originator, allow-check-password\n};|g"`
    DSA_KNOWLEDGE_DXC=`echo "$DSA_KNOWLEDGE_DXC"|sed -e "s|anonymous,||g"`
    echo "$DSA_KNOWLEDGE_DXC" > $DXHOME/config/knowledge/$LOCAL_DSA_NAME.dxc

    if [ $NONROOTUSER -eq 0 ]; then
        chown $DXUSER -R $DXHOME
    fi

    echo "  Generating $LOCAL_MONITORING_DSA_NAME certificates ..."  | $LOG
    echo
    #generate certificate
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "dxcertgen -i \"CN=GenCA,O=MonitorMgmtUI,C=AU\" -D $LOCAL_MONITORING_DSA_NAME certs"  >> $INSTALL_LOG 2>&1
        su - $DXUSER -c "dxcertgen -n $DXUIHOME/CA/certs/ca.pem importca"  >> $INSTALL_LOG 2>&1

        echo "  Starting Management UI embedded DSAs ..."  | $LOG
        echo
        #start DSAs
        su - $DXUSER -c "dxserver start $LOCAL_MONITORING_DSA_NAME;dxserver start $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    else
        /bin/sh -c "$DXSRCSH;dxcertgen -i \"CN=GenCA,O=MonitorMgmtUI,C=AU\" -D $LOCAL_MONITORING_DSA_NAME certs"  >> $INSTALL_LOG 2>&1
        /bin/sh -c "$DXSRCSH;dxcertgen -n $DXUIHOME/CA/certs/ca.pem importca"  >> $INSTALL_LOG 2>&1

        echo "  Starting Management UI embedded DSAs ..."  | $LOG
        echo
        #start DSAs
        /bin/sh -c "$DXSRCSH;dxserver start $LOCAL_MONITORING_DSA_NAME;dxserver start $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    fi
}

mgmtui_questions()
{
    echo | $LOG
    echo "========================== MANAGEMENT UI QUESTIONS ============================" | $LOG

    if [ $SKIPUI -eq 1 ]; then  # we already have this version
        echo                                                                   | $LOG
        echo "  A newer/identical version of $DXMGMTUIPROD has been detected." | $LOG
        echo                                                                   | $LOG
        echo "  Existing Version: $UICUR_VERSION"   | $LOG
        echo "  Install Version : $DXVERSIONEX"               | $LOG
        echo                                                                   | $LOG
        RETURN="n"
    elif [ "$UPGRADEUI" = "1" ]; then
        echo                                                                   | $LOG
        echo "  Current installed version of $DXMGMTUIPROD:"                   | $LOG
        echo "  Version $UICUR_VERSION"       | $LOG
        echo                                                                   | $LOG
        echo "  This setup will upgrade it to:"                                | $LOG
        echo "  Version $DXVERSIONEX"                         | $LOG
        if [ $UICUR_MAJOR -eq 12 ]; then
            NO_MONITOR_DSA="y"
        fi
        if [ $DEFANS -eq 1 ]; then
            RETURN="y"
        else
            QUESTION="  Do you want to upgrade it? (y/n)"
            DEFAULT="y"
            get_response ynq
        fi
    elif [ $DEFANS -eq 1 ]; then
        RETURN="y"
    else
        QUESTION="  Do you want to install the $DXMGMTUIPROD software? (y/n/i/q)"
        DEFAULT="y"
        get_response yniq

        # If the answer is i then run the information subroutine
        while [ "$RETURN" = "i" ]; do
            dxmgmtui_info
            QUESTION="  Do you want to install the $DXMGMTUIPROD software? (y/n/i/q)"
            DEFAULT="y"
            get_response yniq
        done        
    fi

    if [ -z "$INSTALLUI" ]; then
        INSTALLUI=$RETURN
    fi

    if [ "$INSTALLUI" = "y" ]; then

        if [ "x$UPGRADEUI" = "x" ] || [ $UPGRADEUI -ne 1 ]; then

            if [ -z "$WRITE_RESPONSE_FILE" ]; then
                # don't run if we're writing a response file
                user_dxserver ## TODO
            fi

            get_ui_new_dir
            ETDIRHOME=`dirname $DXUIHOME`
            DXHOME=$ETDIRHOME/dxserver

            if [ -z "$WRITE_RESPONSE_FILE" ]; then
                # don't run if we're writing a response file
                if [ ! -d $DXUIHOME ]; then
                    mkdir -p $DXUIHOME
                    chown $DXUSER:$DXGROUP $DXUIHOME
                fi
                USERHOMEDIR=`dxpasswdtool getuserhomedir $DXUSER`
                if [ ! -d $USERHOMEDIR ]; then
                    mkdir -p $USERHOMEDIR
                    chown $DXUSER:$DXGROUP $USERHOMEDIR
                fi
            fi
        else
        # Upgrade: no more prompts
            return
        fi

        if [ $DEFANS -eq 0 -o -z "$UIWEBPORT" ]; then
            QUESTION="  Enter the port for the Management UI web server"
            DEFAULT=3000
            get_response port
            UIWEBPORT=$RETURN
        fi
        # check for FQDN
        hostname | grep "\." > /dev/null
        if [ $? -eq 0 ]; then
        HOSTNAME=`hostname | awk -F. '{print $1}'`
        else
            HOSTNAME=`hostname`
        fi
        HOSTNAME_FQDN=`hostname -f`
        if [ $? -ne 0 ] || [ -z "$HOSTNAME_FQDN" ]; then
            echo "Unable to obtain hostname FQDN. Installation aborted."
            exit 1
        fi
        if [ $DEFANS -eq 0 -o -z "$USEOWNWEBCERT" ]; then
            QUESTION="  Do you want to use your own certificates to secure Management UI web server communications? (y/n/q)"
            DEFAULT="n"
            get_response ynq
            USEOWNWEBCERT=$RETURN
        fi

        if [ "$USEOWNWEBCERT" = "y" ]; then
            while [ "x$UIWEBCERTPATH" = "x" ]; do
                while [ "x$UIWEBCERTPATH" = "x" ]; do
                    QUESTION="  Enter path to the certificate pem file"
                    DEFAULT=
                    get_response path
                    if [ "x$RETURN" = "x" ]; then continue; fi
                    if [ -r $RETURN ]; then
                        openssl x509 -in "$RETURN" -text -noout > /dev/null 2>&1
                        if [ $? -eq 0 ]; then
                            MOD1=`openssl x509 -noout -modulus -in "$RETURN"` > /dev/null 2>&1
                            if [ $? -eq 0 ]; then
                                UIWEBCERTPATH=$RETURN
                            else
                                echo "    cannot retrieve modulus from $RETURN"
                            fi
                        else
                            echo "    $RETURN is not a valid certificate"
                        fi
                    else
                        echo "    cannot access $RETURN"
                    fi
                done
                while [ "x$UIWEBPRIVKEYPATH" = "x" ]; do
                    QUESTION="  Enter path to the private key pem file"
                    DEFAULT=
                    get_response path
                    if [ "x$RETURN" = "x" ]; then continue; fi
                    if [ -r $RETURN ]; then
                        openssl rsa -in "$RETURN" -check > /dev/null 2>&1
                        if [ $? -eq 0 ]; then
                            MOD2=`openssl rsa -noout -modulus -in "$RETURN"` > /dev/null 2>&1
                            if [ $? -eq 0 ]; then
                                UIWEBPRIVKEYPATH=$RETURN
                            else
                                echo "    cannot retrieve modulus from $RETURN"
                            fi
                        else
                            echo "    $RETURN is not a valid private key"
                        fi
                    else
                        echo "    cannot access $RETURN"
                    fi
                done
                if [ "$MOD1" != "$MOD2" ]; then
                        UIWEBCERTPATH=""
                        UIWEBPRIVKEYPATH=""
                        echo "The certificate and the private key do not match"
                fi
            done
        else
            UIWEBCERTPATH=$DXUIHOME/out/webservercert.pem
            UIWEBPRIVKEYPATH=$DXUIHOME/out/webservercert.key
        fi

        if [ $DEFANS -eq 0 -o -z "$UIDSAPORTLOCAL" ]; then
            ADD_MORE_DSAS=y
            QUESTION="  Enter the port for the Management UI DSA"
            DEFAULT=10389
            get_response port
            UIDSAPORTLOCAL=$RETURN
        fi

        if [ $DEFANS -eq 0 -o -z "$ADMINUSERPWD" ]; then
            while [ 1 ]; do
                echo | $LOG
                echo "Password quality rules for admin user:" | $LOG
                $SOURCEDIR/dxppcheck -l -f "$SOURCEDIR/passwdPolicy.txt" | $LOG
                echo | $LOG
                echo $LINUX_USE_BACKSLASHES "  Enter admin user password: \c"
                stty -echo
                read ADMINUSERPWD
                stty echo
                echo | $LOG

                # Check password policy compliance
                MSG=`$SOURCEDIR/dxppcheck -u admin -p "$ADMINUSERPWD" -f "$SOURCEDIR/passwdPolicy.txt"`
                RC=$?
                if [ $RC -lt 200 ]; then
                    if [ $RC != 0 ]; then
                        echo "  Cannot check password quality, error code: $RC. Proceeding without password quality check." | $LOG
                        echo | $LOG
                    fi
                    rm -f dxalarm.log
                    echo $LINUX_USE_BACKSLASHES "  Confirm admin user password: \c"
                    stty -echo
                    read ADMINUSERPWD2
                    stty echo
                    echo | $LOG

                    if [ "$ADMINUSERPWD" = "$ADMINUSERPWD2" ]; then
                        break
                    else
                        echo "  Passwords do not match, please try again." | $LOG
                        echo | $LOG
                    fi
                else
                    echo $MSG |$LOG
                fi
            done
        fi
    fi
}

gen_certs()
{
    if [ "$USEOWNWEBCERT" = "n" ]; then
    echo "  Generating webserver certificates..."  | $LOG
    echo
    HOSTNAME_FQDN=`hostname -f`
    if [ $? -ne 0 ] || [ -z "$HOSTNAME_FQDN" ]; then
        echo "Unable to obtain hostname FQDN. Installation aborted."
        exit 1
    fi
    cp $SOURCEDIR/generate_cert_key.sh $DXUIHOME
    cp $SOURCEDIR/setup_ca.sh $DXUIHOME
    cp $SOURCEDIR/openssl-ca/openssl-ca.cnf $DXUIHOME
    cp $SOURCEDIR/openssl-ca/openssl-req.cnf $DXUIHOME
    cat $SOURCEDIR/create_webserver_certificate.sh | \
    sed -e "s|__HOSTNAME_FQDN__|$HOSTNAME_FQDN|g" \
    -e "s|__HOSTNAME__|webservercert|g" > $DXUIHOME/create_webserver_certificate.sh
    chmod a+x $DXUIHOME/create_webserver_certificate.sh
    chown -R $DXUSER $DXUIHOME
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "cd $DXUIHOME; ./create_webserver_certificate.sh" >> $INSTALL_LOG 2>&1
    else
        /bin/sh -c "$DXSRCSH;cd $DXUIHOME; ./create_webserver_certificate.sh" >> $INSTALL_LOG 2>&1
    fi
    rm $DXUIHOME/generate_cert_key.sh $DXUIHOME/create_webserver_certificate.sh $DXUIHOME/setup_ca.sh $DXUIHOME/openssl-ca.cnf $DXUIHOME/openssl-req.cnf
    fi
}

run_load_files()
{
    if [ "$INSTALLUI" = "n" ]; then
        return
    fi

    echo | $LOG
    echo "==================== LOAD $DXMGMTUIPROD FILES ====================" | $LOG

# expand management UI files
    DIRECTORYDIR=`dirname $DXHOME`
    if [ "$UPGRADEUI" = "1" ]; then
    echo "  Stopping $DXMGMTUIPROD nodejs server..."  | $LOG
    echo
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "${DXUIHOME}/stop_dxmgmtui"  >> $INSTALL_LOG 2>&1
    else
        /bin/sh -c "$DXSRCSH;${DXUIHOME}/stop_dxmgmtui"  >> $INSTALL_LOG 2>&1
    fi
        SAVE_CONFIG_JS=`mktemp`
        cp -pf $DIRECTORYDIR/management-ui/config.js $SAVE_CONFIG_JS
        SAVE_CERTS_KEYS=`mktemp -d`
        cp -pf $DIRECTORYDIR/management-ui/api-server/certs/* $SAVE_CERTS_KEYS
        SAVE_CA_CERTS=`mktemp -d`
        if [ "$USEOWNWEBCERT" = "y" ]; then
            NO_OWN_CA_CERT=1 #TODO: We need to ask a user to provide CA cert chain
        else
            if [ ! -d "$DIRECTORYDIR/management-ui/CA/" ]; then
                # DE309137: /opt/CA/Directory/management-ui/CA/ removed when management UI 12.5.01 upgraded to 12.6.03
                # Certificates must be re-generated
                gen_certs
            cp -pf $DXUIHOME/out/* SAVE_CERTS_KEYS
            fi
        fi
        cp -prf $DIRECTORYDIR/management-ui/CA/ $SAVE_CA_CERTS
        if [ -e "${DXUIHOME}/dxscimserver" ]; then
            echo "  Stopping SCIM server..."  | $LOG
            echo
            if [ $NONROOTUSER -eq 0 ]; then
                su - $DXUSER -c "${DXUIHOME}/dxscimserver stop"  >> $INSTALL_LOG 2>&1
            else
                /bin/sh -c "$DXSRCSH;${DXUIHOME}/dxscimserver stop"  >> $INSTALL_LOG 2>&1
            fi
        fi
        SAVE_CONFIG_SCIM_JS=`mktemp`
        if [ -e "$DIRECTORYDIR/management-ui/config-scim.js" ]; then
            cp -pf $DIRECTORYDIR/management-ui/config-scim.js $SAVE_CONFIG_SCIM_JS
        fi
        rm -rf $DIRECTORYDIR/management-ui
    fi
    mkdir -p $DIRECTORYDIR/management-ui
    cd $DIRECTORYDIR/management-ui
    DXUIHOME=`pwd`

    echo "  Loading $DXMGMTUIPROD files..."  | $LOG
    echo

    if expr $DXUITAR : '.*\.tar\.Z$' >/dev/null
    then
        zcat $DXUITAR | tar xf -
    elif expr $DXUITAR : '.*\.tar\.gz$' >/dev/null
    then
        zcat $DXUITAR | tar xf -
    else
        tar xf $DXUITAR
    fi 
    if [ $? != 0 ]
    then
        echo "  ERROR - Load of $DXMGMTUIPROD product files failed" | $LOG
        exit 1
    fi

}

run_mgmtui_install()
{
    DIRECTORYDIR=`dirname $DXHOME`
    cd $DIRECTORYDIR/management-ui
    if [ "x$DXUIHOME" = "x" ]; then
        DXUIHOME=`pwd`
    fi
    mkdir -p ${DXUIHOME}/pid
    mkdir -p ${DXUIHOME}/CA/certs

    chown -R $DXUSER $DXUIHOME | $LOG
    chgrp -R $DXGROUP $DXUIHOME | $LOG

    if [ "$INSTALLUI" = "n" ]; then
        return
    fi

    echo | $LOG
    echo "========================= MANAGEMENT UI INSTALLATION ==========================" | $LOG
    echo | $LOG
    LOCAL_DSA_NAME=$(hostname)-management-ui
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "dxserver status $LOCAL_DSA_NAME | grep $LOCAL_DSA_NAME" >/dev/null 2>&1
    else
        /bin/sh -c "$DXSRCSH;dxserver status $LOCAL_DSA_NAME | grep $LOCAL_DSA_NAME" >/dev/null 2>&1
    fi
    if [ $? -eq 0 ]; then DSA_ALREADY_INSTALLED="y"; fi

    # Copy Management UI embedded DSA schema iles
    cp $SOURCEDIR/management-ui.dxc $DXHOME/config/schema/
    cp $SOURCEDIR/management-ui-access.dxc $DXHOME/config/access/
    
    if [ "$UPGRADEUI" = "1" ]; then
		# Adding Password-history settings, if not present to restrict user from changing password to the last two passwords
		if [ -f "$DXHOME/config/servers/$LOCAL_DSA_NAME.dxi" ]; then
			CHECK=`grep -q "password-history" "$DXHOME/config/servers/$LOCAL_DSA_NAME.dxi"`
				if [ $? -ne "0" ]; then
					echo "  Modifying Management UI embedded DSAs configuration ..."  | $LOG
					echo
					ADD_PWD_HISTORY_CONFIG=`cat $DXHOME/config/servers/$LOCAL_DSA_NAME.dxi`
					ADD_PWD_HISTORY_CONFIG=`echo "$ADD_PWD_HISTORY_CONFIG"|sed -e 's|set password-max-suspension = 10;|set password-max-suspension = 10;\nset password-history = 2;\nset password-enforce-quality-on-reset = true;|g'`
					echo "$ADD_PWD_HISTORY_CONFIG" > $DXHOME/config/servers/$LOCAL_DSA_NAME.dxi
				fi
		fi
		
        # This is upgrade: restore original config.js and certs
        mv -f $SAVE_CONFIG_JS $DIRECTORYDIR/management-ui/config.js
        cp -pf $SAVE_CERTS_KEYS/* $DIRECTORYDIR/management-ui/api-server/certs
        if [ -e "$DIRECTORYDIR/management-ui/api-server/certs/$(hostname).pem" ] && [ ! -e "$DIRECTORYDIR/management-ui/api-server/certs/webservercert.pem" ]; then
            cp -fp $DIRECTORYDIR/management-ui/api-server/certs/$(hostname).pem $DIRECTORYDIR/management-ui/api-server/certs/webservercert.pem
            cp -fp $DIRECTORYDIR/management-ui/api-server/certs/$(hostname).key $DIRECTORYDIR/management-ui/api-server/certs/webservercert.key
        fi
	
        mkdir -p $DIRECTORYDIR/management-ui/out
        mv -f $SAVE_CERTS_KEYS/* $DIRECTORYDIR/management-ui/out
        cp -prf $SAVE_CA_CERTS/* $DIRECTORYDIR/management-ui
        rm -rf $SAVE_CONFIG_JS $SAVE_CERTS_KEYS $SAVE_CA_CERTS
        chown -R $DXUSER $DXUIHOME
        echo "  Starting $DXMGMTUIPROD nodejs server..."  | $LOG
        echo
        if [ $NONROOTUSER -eq 0 ]; then
            su - $DXUSER -c "${DXUIHOME}/dxmgmtuiserver start"  >> $INSTALL_LOG 2>&1
        else
            /bin/sh -c "$DXSRCSH;${DXUIHOME}/dxmgmtuiserver start"  >> $INSTALL_LOG 2>&1
        fi
        return
    fi

    gen_certs

    cp $UIWEBCERTPATH $DXUIHOME/api-server/certs/
    server_cert=`basename $UIWEBCERTPATH`
    cp $UIWEBPRIVKEYPATH $DXUIHOME/api-server/certs/
    server_key=`basename $UIWEBPRIVKEYPATH`

    #add web port number, certificate and private key path to config.js
    if [ "$USEOWNWEBCERT" = "y" ]; then
        cp $UIWEBCACERTPATH $DXUIHOME/CA/certs

        SSL_CONFIG=`cat $DXUIHOME/config-default.js|grep -A 1000 "module.exports.sslConfig"|grep -m 1 -B 1000 "};"`
        SSL_CONFIG=`echo "$SSL_CONFIG"|sed -e "s|'webservercert.pem'|'$server_cert'|"`
        SSL_CONFIG=`echo "$SSL_CONFIG"|sed -e "s|'webservercert.key'|'$server_key'|"`
        echo >> $DXUIHOME/config.js
        echo "$SSL_CONFIG" >> $DXUIHOME/config.js
        echo >> $DXUIHOME/config.js
    fi
    if [ $UIWEBPORT -ne 3000 ]; then
        echo >> $DXUIHOME/config.js
        echo "module.exports.port = $UIWEBPORT;" >> $DXUIHOME/config.js
        echo >> $DXUIHOME/config.js
    fi
    
    #create and configure new DSA
    #Check if embedded DSA already exists
    RNDPASSWD=`openssl rand -base64 32`

    LDIF=`cat $SOURCEDIR/management-ui.ldif`
    LDIF=`echo "$LDIF"|sed -e "s|userPassword: changeme|userPassword: $RNDPASSWD|g"`
    if [ ! "x$ADMINUSERPWD" = "x" ]; then
        LDIF=`echo "$LDIF"|sed -e "s|userPassword: C@D1r3ct0ry|userPassword: $ADMINUSERPWD|g"`
    fi
    echo "$LDIF" > $DXHOME/management-ui.ldif
    
    if [ "x$DSA_ALREADY_INSTALLED" = "x" ]; then
        echo "  Creating embedded DSA $LOCAL_DSA_NAME ..."  | $LOG
        echo
        if [ $NONROOTUSER -eq 0 ]; then
            su - $DXUSER -c "dxnewdsa $LOCAL_DSA_NAME $UIDSAPORTLOCAL o=management-ui; dxserver stop $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
        else
            /bin/sh -c "$DXSRCSH;dxnewdsa $LOCAL_DSA_NAME $UIDSAPORTLOCAL o=management-ui; dxserver stop $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
        fi
        DSA_SERVER_DXI=`cat $DXHOME/config/servers/$LOCAL_DSA_NAME.dxi`
        DSA_SERVER_DXI=`echo "$DSA_SERVER_DXI"|sed -e "s|source \"\.\.\/schema\/default.dxg\";|source \"\.\.\/schema\/x500.dxc\";\nsource \"\.\.\/schema\/dxserver.dxc\";\nsource \"\.\.\/schema\/management-ui.dxc\";|g"`
        DSA_SERVER_DXI=`echo "$DSA_SERVER_DXI"|sed -e "s|source \"\.\.\/access\/default.dxc\";|source \"\.\.\/access\/management-ui-access.dxc\";|g"`
        echo "$DSA_SERVER_DXI" > $DXHOME/config/servers/$LOCAL_DSA_NAME.dxi
        cat $SOURCEDIR/passwdPolicy.txt >> $DXHOME/config/servers/$LOCAL_DSA_NAME.dxi
        
        DSA_KNOWLEDGE_DXC=`cat $DXHOME/config/knowledge/$LOCAL_DSA_NAME.dxc`
        DSA_KNOWLEDGE_DXC=`echo "$DSA_KNOWLEDGE_DXC"|sed -e "s|};|\n    dsa-flags = multi-write, no-service-while-recovering\n};|g"`
        echo "$DSA_KNOWLEDGE_DXC" > $DXHOME/config/knowledge/$LOCAL_DSA_NAME.dxc
        chown $DXUSER -R $DXHOME
        if [ $NONROOTUSER -eq 0 ]; then
            su - $DXUSER -c "dxloaddb $LOCAL_DSA_NAME $DXHOME/management-ui.ldif"  >> $INSTALL_LOG 2>&1
        else
            /bin/sh -c "$DXSRCSH;dxloaddb $LOCAL_DSA_NAME $DXHOME/management-ui.ldif"  >> $INSTALL_LOG 2>&1
        fi
    fi
    UIDSAPASS=`cat $DXHOME/management-ui.ldif |grep -m 1 userPassword|awk -F': ' '{print $2}'`
    if [ $NONROOTUSER -eq 0 ]; then
        UIDSAPASSENC=`su - $DXUSER -c "$DXHOME/bin/dxpassword -P CADIR $UIDSAPASS"`  >> $INSTALL_LOG 2>&1
    else
        UIDSAPASSENC=`/bin/sh -c "$DXSRCSH;$DXHOME/bin/dxpassword -P CADIR $UIDSAPASS"`  >> $INSTALL_LOG 2>&1
    fi

    knowledge=`cat $DXHOME/config/knowledge/$LOCAL_DSA_NAME.dxc`
    echo "  Configuring $DXMGMTUIPROD node.js environment..."  | $LOG
    echo
    #add provided DSAs details to config.js
    LDAPCLIENTCONFIG=`cat $DXUIHOME/config-default.js|grep -A 1000 "module.exports.ldapClientConfig"|grep -m 1 -B 1000 "];"`
    LDAPCLIENTCONFIG=`echo "$LDAPCLIENTCONFIG"|sed -e "s|10389|$UIDSAPORTLOCAL|" -e "s|bindCredentials: 'superuser'|bindCredentials: '$UIDSAPASSENC'|"`
    echo >> $DXUIHOME/config.js
    echo "$LDAPCLIENTCONFIG" >> $DXUIHOME/config.js
    echo >> $DXUIHOME/config.js

    #restart local DSA and register to start on reboot
    echo "  Stopping $LOCAL_DSA_NAME DSA ..."  | $LOG
    echo
    chown $DXUSER -R $DXHOME/config/
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "dxserver stop $LOCAL_DSA_NAME;dxserver install $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    else
        /bin/sh -c "$DXSRCSH;dxserver stop $LOCAL_DSA_NAME;dxserver install $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    fi

    #generate certificate
    echo "  Generating $LOCAL_DSA_NAME certificates ..."  | $LOG
    echo
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "dxcertgen -i \"CN=GenCA,O=MgmtUI,C=AU\" -D $LOCAL_DSA_NAME certs"  >> $INSTALL_LOG 2>&1
    else
        /bin/sh -c "$DXSRCSH;dxcertgen -i \"CN=GenCA,O=MgmtUI,C=AU\" -D $LOCAL_DSA_NAME certs"  >> $INSTALL_LOG 2>&1
    fi

    chown -R $DXUSER $DXUIHOME

    #restart local DSA and register to start on reboot
    if [ $NONROOTUSER -eq 0 ]; then
        echo "  Starting $LOCAL_DSA_NAME DSA ..."  | $LOG
        echo
        su - $DXUSER -c "dxserver start $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    else
        echo "  Starting $LOCAL_DSA_NAME DSA ..."  | $LOG
        echo
        /bin/sh -c "$DXSRCSH;dxserver start $LOCAL_DSA_NAME"  >> $INSTALL_LOG 2>&1
    fi
# Cleanup
    rm -f $DXHOME/management-ui.ldif
}

#
#   The encrypt_config_data is implemented to encode passwords
#   in config.js and config-scim.js files. If the passwords
#   are encoded they are not encoded again.
#   Once all the config files are encoded (after 14.1 SP1 EOS)
#   the code can be removed. Having the code does not harm but
#   it does unnecessary check.
#

encrypt_config_data()
{
    if [ "$UPGRADEUI" = "1" ]; then

       echo " Encoding config files  "  | $LOG
       echo
       if [ $NONROOTUSER -eq 0 ]; then
            su - $DXUSER -c "cp $SOURCEDIR/encconfigdata.js $DXUIHOME/ && cd $DXUIHOME && $DXUIHOME/node.js/bin/node $DXUIHOME/encconfigdata.js"  >> $INSTALL_LOG 2>&1
            RETVAL=$?
            su - $DXUSER -c "rm -f $DXUIHOME/encconfigdata.js"  >> $INSTALL_LOG 2>&1
       else
            /bin/sh -c "$DXSRCSH; cp $SOURCEDIR/encconfigdata.js $DXUIHOME/ && cd $DXUIHOME && $DXUIHOME/node.js/bin/node $DXUIHOME/encconfigdata.js"  >> $INSTALL_LOG 2>&1
            RETVAL=$?
            /bin/sh -c "$DXSRCSH; rm -f $DXUIHOME/encconfigdata.js"  >> $INSTALL_LOG 2>&1
       fi
       if [ $RETVAL -eq 1 ] || [ $RETVAL -eq 3 ]; then
            echo "  Restarting $DXMGMTUIPROD nodejs server..."  | $LOG
            echo
            if [ $NONROOTUSER -eq 0 ]; then
                su - $DXUSER -c "${DXUIHOME}/dxmgmtuiserver stop"  >> $INSTALL_LOG 2>&1
                su - $DXUSER -c "${DXUIHOME}/dxmgmtuiserver start"  >> $INSTALL_LOG 2>&1
            else
                /bin/sh -c "$DXSRCSH;${DXUIHOME}/dxmgmtuiserver stop"  >> $INSTALL_LOG 2>&1
                /bin/sh -c "$DXSRCSH;${DXUIHOME}/dxmgmtuiserver start"  >> $INSTALL_LOG 2>&1
            fi
        fi 

        if [ $RETVAL -eq 2 ] || [ $RETVAL -eq 3 ]; then
            echo "  Restarting SCIM server..."  | $LOG
            echo
            if [ $NONROOTUSER -eq 0 ]; then
                su - $DXUSER -c "${DXUIHOME}/dxscimserver stop"  >> $INSTALL_LOG 2>&1
                su - $DXUSER -c "${DXUIHOME}/dxscimserver start"  >> $INSTALL_LOG 2>&1
            else
                /bin/sh -c "$DXSRCSH;${DXUIHOME}/dxscimserver stop"  >> $INSTALL_LOG 2>&1
                /bin/sh -c "$DXSRCSH;${DXUIHOME}/dxscimserver start"  >> $INSTALL_LOG 2>&1
            fi
        fi
   
    fi

}

##############################
# Installation Complete Sign #
##############################
installation_complete()
{
    echo | $LOG
    echo "=========================== INSTALLATION COMPLETE =============================" | $LOG
    echo | $LOG
    echo "  Changing group ownership and file permissions" | $LOG
    if [ $NONROOTUSER -eq 1 ]; then
         echo | $LOG
         echo "PLEASE NOTE THAT THE DSAs WILL NOT START AUTOMATICALLY ON BOOT BECAUSE THIS IS A NON-ROOT INSTALLATION. PLEASE ASK YOUR SYSTEM ADMINISTRATOR TO SET THIS UP." | $LOG
    else
        if [ `uname` = "SunOS" -a ! "x$LEGACY_SETUID" = "xy" ]; then
            PFSHELL=`echo $DXSHELL |grep "\/pf"`
            if [ $? -ne 0 ]; then
                SHELL=`basename $DXSHELL`
                if [ "$SHELL" = "sh" -o "$SHELL" = "csh" ];then
                    DXSHELL_NEW=/bin/pf$SHELL
                elif [ "$SHELL" = "ksh" ];then
                    DXSHELL_NEW=/usr/bin/pfksh
                else
                    DXSHELL_NEW=/bin/pfsh
                fi
                echo "Changing $DXUSER default login shell $DXSHELL to $DXSHELL_NEW because 'net_privaddr' approach is used to allow listening on ports <= 1024" | $LOG
                usermod -s $DXSHELL_NEW $DXUSER
            fi
        fi
    fi

    if [ -d $DXUIHOME ]; then
        chmod -R go= $DXUIHOME | $LOG
        chmod -R g+r $DXUIHOME/logs | $LOG
    fi
    if [ -d $DXHOME ]; then
        chmod -R o= $DXHOME | $LOG
        chmod -R go= $DXHOME/config/servers/$(hostname)-monitoring-management-ui.dxi | $LOG
        if [ $NONROOTUSER -eq 0 ]; then
            chgrp -R $DXGROUP $DXHOME | $LOG
            chown $DXUSER $DXHOME/logs/*.* | $LOG
        fi
        for filename in `ls $DXHOME/config/servers/*.dxi 2>/dev/null`; do
            chown $DXUSER $filename | $LOG
        done
        for filename in `ls $DXHOME/config/ssld/*.dxc 2>/dev/null`; do
            chown $DXUSER $filename | $LOG
        done

        if [ "$SETUID" = "y" ]; then
            # doublecheck SUIDs
            for filename in bin/dxserver bin/dxadmind
            do
        setuid $DXHOME/$filename
            done
        fi

        # make default config and schema files read-only
        chmod ug-w `find $DXHOME/config -name "default.*" -print`  | $LOG

        if expr $DXTAR : '.*\.tar\.Z$' >/dev/null
        then
            CMD="zcat $DXTAR |tar tf - | grep config/schema" 
        elif expr $DXTAR : '.*\.tar\.gz$' >/dev/null
        then
            CMD="zcat $DXTAR |tar tf - | grep config/schema" 
        else
            CMD="tar tf $DXTAR | grep config/schema"
        fi
        for FILE in `eval $CMD`
        do
            if [ -f $DXHOME/$FILE ]; then
                chmod ug-w $DXHOME/$FILE  | $LOG
            fi
        done
    fi

    # readmes
    if [ -d $DXHOME ]; then
        cd $DXHOME/..
    fi
    if [ -f relnotes ]; then
        RELNOTE_BLD=`cat -v relnotes | egrep 'Update|Build' | awk 'NR==1 {print $NF}'`  > /dev/null 2>&1
    fi
    if [ "x$RELNOTE_BLD" = "x" ]; then
        RELNOTE_BLD=0
    fi
    if [ $BLDNUM -gt $RELNOTE_BLD ]; then
        rm -rf readme* > /dev/null 2>&1
        rm -rf relnotes > /dev/null 2>&1
        if [ -f $SOURCEDIR/../../readme ]; then
            cp $SOURCEDIR/../../readme .
            cp $SOURCEDIR/../../readme.html .
            cp $SOURCEDIR/../../relnotes .
        else
            cp $SOURCEDIR/../../../readme .
            cp $SOURCEDIR/../../../readme.html .
            cp $SOURCEDIR/../../../relnotes .
        fi
    fi

    echo | $LOG
    echo "  Install completed: `date`"  | $LOG
    if [ "$INSTALLDX" = "y" ]; then
        if [ $NONROOTUSER -eq 0 ]; then
            su - $DXUSER -c "dxserver version" >> $INSTALL_LOG
        else
            /bin/sh -c "$DXSRCSH;dxserver version" >> $INSTALL_LOG
        fi
    fi

    if [ $DEFANS -eq 1  -a -z "$EXPRESS" ] && [ -n "$DXUSER_CREATED" ]; then
        echo  | $LOG
        echo "  ===================================================================" | $LOG
        echo "   Please note, the $DXUSER was created during this installation."     | $LOG
        echo "   It has been added WITHOUT A PASSWORD. You must run the 'passwd'  "  | $LOG
        echo "   utility to assign a password to this user."                         | $LOG
        echo "  ===================================================================" | $LOG
    fi

    # restart services
    if [ "$NOLOAD" != "yes" ]; then
        start_dxservers # starts previously running DSAs
    else
        echo "RESTARTLIST=\"$RESTARTLIST\"" >> $DXHOME/cadir_noload_list.txt
    fi 
    start_dxadminds # starts previously running dxadmind's 
    start_tlsclients # starts previously running dxadmind's 

    if [ $NONROOTUSER -eq 0 ]; then
        chgrp $DXGROUP readme readme.html relnotes | $LOG
        chown $DXUSER readme readme.html relnotes | $LOG
    fi

    echo | $LOG
    echo | $LOG
    echo "              ***********************************" | $LOG
    echo "              ****** Installation Complete ******" | $LOG
    echo "              ***********************************" | $LOG

    if [ -n "$DBERROR" ]; then
        echo | $LOG
        echo "  Errors were encountered upgrading the $DXPROD databases." | $LOG
        echo "  Details have been written to $INSTALL_LOG_NAME " | $LOG
    fi
    
    rm -rf $DXHOME/.hushlogin > /dev/null 2>&1
    
        if [ $RESTOREERROR -eq 0 ]; then
            return 0
        else
            echo 
            echo "  There was a problem with the restore phase of the install. " | $LOG
            return 1
        fi
}

################################################################################
# invoke mainline                                                              #
################################################################################

##################
# Set up logging #
##################
    INSTALL_LOG=/tmp/$INSTALL_LOG_NAME
    #INSTALL_LOG=/opt/CA/Directory/$INSTALL_LOG_NAME
    LOG="tee -a $INSTALL_LOG"
    # Add $LOG to the end of any statements that require logging
    export INSTALL_LOG LOG

    # Clean-up any logs from failed installs
    if [ -f $INSTALL_LOG ]; then
        rm $INSTALL_LOG
    fi
    touch $INSTALL_LOG
    chmod 666 $INSTALL_LOG
    umask 022
    echo `date` >> $INSTALL_LOG

##########################################################
# Set up arguments files for the command line switches   #
#                                                        #
# -nosamples, -nodxwebserver, -default, -dxuser #
# -responsefile  -write_responses                        #
##########################################################
echo "dxmgmtuisetup" >> $INSTALL_LOG
while [ $# -gt 0 ]; do
    arg=$1
    shift

    if [ $arg = "-r" ]; then
        if [ $# -gt 0 ]; then
            if [ "`echo $1 | cut -c 1`" != "-" ]; then
                SOURCEDIR=$1
                if [ -z "$SOURCEDIR" ] || [ "$SOURCEDIR" = "" ]; then
                    echo "  -r must not be blank"
                    echo "  Installation terminated."
                    exit 1
                fi
                RESPONSE_FILE=$SOURCEDIR/responsefile.txt
                shift
                echo "-r $SOURCEDIR" >> $INSTALL_LOG
                continue
            fi
        fi
        echo "  You must provide an argument to -r."
        echo "  Installation terminated."
        exit 1

    elif [ $arg = "-responsefile" ]; then
        if [ $# -gt 0 ]; then
            if [ "`echo $1 | cut -c 1`" != "-" ]; then
                RESPONSE_FILE="$1"
                RSP=1 # do not show licence (or initial_screens)
                if [ -z "$RESPONSE_FILE" ] || [ "$RESPONSE_FILE" = "" ]; then
                    echo "  -responsefile must not be blank"
                    echo "  Installation terminated."
                    exit 1
                fi
                #13852 - need the full path to responsefile
                if [ `echo $RESPONSE_FILE | cut -c 1-1` != "/" ]; then 
                    RESPONSE_FILE=`pwd`/$RESPONSE_FILE
                fi
                shift
                echo "-responsefile $RESPONSE_FILE" >> $INSTALL_LOG
                continue                
            fi
          fi
        echo "  You must provide an argument to -responsefile."
        echo "  Installation terminated."
        exit 1

    elif [ $arg = "-dxuser" ]; then
        if [ $# -gt 0 ]; then
            if [ "`echo $1 | cut -c 1`" != "-" ]; then
                DXUSER="$1"
                DXUSER_PARAM=y
                if [ -z "$DXUSER" ] || [ "$DXUSER" = "" ]; then
                    echo "  -dxuser must not be blank"
                    echo "  Installation terminated."
                    exit 1
                fi
                shift
                echo "-dxuser $DXUSER" >> $INSTALL_LOG
                continue
            fi
        fi
        echo "  You must provide an argument to -dxuser."
        echo "  Installation terminated."
        exit 1

    elif [ $arg = "-dxagentpass" ]; then
        if [ $# -gt 0 ]; then
            if [ "`echo $1 | cut -c 1`" != "-" ]; then
                DXAGENTPASS="$1"
                if [ -z "$DXAGENTPASS" ] || [ "$DXAGENTPASS" = "" ]; then
                    echo "  -dxagentpass must not be blank"
                    echo "  Installation terminated."
                    exit 1
                fi
                shift
                echo "-dxagentpass X" >> $INSTALL_LOG
                continue
            fi
        fi
        echo "  You must provide an argument to -dxagentpass."
        echo "  Installation terminated."
        exit 1
    elif [ $arg = "-dxmasterkeypass" ]; then
        if [ $# -gt 0 ]; then
            if [ "`echo $1 | cut -c 1`" != "-" ]; then
                DXMASTERKEYPASS="$1"
                if [ -z "$DXMASTERKEYPASS" ] || [ "$DXMASTERKEYPASS" = "" ]; then
                    echo "  -dxmasterkeypass must not be blank"
                    echo "  Installation terminated."
                    exit 1
                fi
                shift
                echo "-dxmasterkeypass X" >> $INSTALL_LOG
                continue
            fi
        fi
        echo "  You must provide an argument to -dxmasterkeypass."
        echo "  Installation terminated."
        exit 1
    elif [ $arg = "-adminpass" ]; then
        if [ $# -gt 0 ]; then
            if [ "`echo $1 | cut -c 1`" != "-" ]; then
                ADMINUSERPWD="$1"
                if [ -z "$ADMINUSERPWD" ] || [ "$ADMINUSERPWD" = "" ]; then
                    echo "  -adminpass must not be blank"
                    echo "  Installation terminated."
                    exit 1
                fi
                shift
                echo "-adminpass X" >> $INSTALL_LOG
                continue
            fi
        fi
        echo "  You must provide an argument to -adminpass."
        echo "  Installation terminated."
        exit 1

    elif [ $arg = "-nosamples" ]; then     # do not Install any Samples.
        NOSAMPLES=1
        echo "-nosamples" >> $INSTALL_LOG

    elif [ $arg = "-default" ]; then       # use default answers from responsefile.
        DEFANS=1
        echo "-default" >> $INSTALL_LOG

    elif [ $arg = "-silent" ]; then        # same as -default
        DEFANS=1
        echo "-silent" >> $INSTALL_LOG

    elif [ $arg = "-write_responses" ]; then # create a responsefile
        if [ $# -gt 0 ]; then
            if [ "`echo $1 | cut -c 1`" != "-" ]; then
                #13206: Response file should be created in current dir if no dir is specified. 
                if [ "`echo $1 | cut -c 1`" = "/" ]; then 
                    WRITE_RESPONSE_FILE="$1"
                else
                    WRITE_RESPONSE_FILE="`pwd`/$1"
                fi
                shift
                echo "-write_responses $WRITE_RESPONSE_FILE" >> $INSTALL_LOG
                WRITE_RESPONSE_FILE_OK=1
                continue
            fi
        fi
        # blank responsefile is okay - we'll just use the default
        WRITE_RESPONSE_FILE="DEFAULT"
        echo "-write_responses $WRITE_RESPONSE_FILE" >> $INSTALL_LOG

    elif [ $arg = "-check_kernel" ]; then # check kernel parameters
        CHECK_KERNEL=1
        echo "-check_kernel" >> $INSTALL_LOG

    elif [ $arg = "-reboot_kernel" ]; then # edit kernel parameters, and reboot y/n
        if [ $# -gt 0 ]; then
            if [ "`echo $1 | cut -c 1`" != "-" ]; then
                case "$1" in
                    [Yy]*) REBOOT_KERNEL="y" ;;
                        *) REBOOT_KERNEL="n" ;;
                esac
                shift
                echo "-reboot_kernel $REBOOT_KERNEL" >> $INSTALL_LOG
                continue
            fi
        fi
        # blank ans is okay - default is "n"
        REBOOT_KERNEL="n"
        echo "-reboot_kernel $REBOOT_KERNEL" >> $INSTALL_LOG

    elif [ $arg = "-list_callers" ]; then 
        echo "  -list_callers parameter deprecated."
        echo "  Installation terminated."
        exit 1
        
    elif [ $arg = "-dxgridsize" ]; then
        if [ $# -gt 0 ]; then
                if [ "`echo $1 | cut -c 1`" != "-" ]; then
                    DXGRIDSIZE="$1"
                    export DXGRIDSIZE
                    shift
                    echo "-dxgridsize $DXGRIDSIZE" >> $INSTALL_LOG
                    continue
                fi
         fi
         echo "  You must provide an argument to -dxgridsize."
         echo "  Installation terminated."
         exit 1
    
    elif [ $arg = "-no_load" ]; then
        NOLOAD="yes"
        echo "  no_load flag has been set." >> $INSTALL_LOG
    else 
        echo "unknown argument $arg" >> $INSTALL_LOG
    fi
done

main

