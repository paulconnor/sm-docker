#!/bin/sh
# Computer Associates DXserver Setup DSA Script 
# $Id: dxsetupdsa.sh,v 1.65 2015/05/18 04:22:29 dmytry Exp $

#################################################################################
# Install the DXserver software.  Runs as DXserver administrator (normally dsa) #
#################################################################################

########################################################################
# The following variables need to be available (exported) from calling #
# routine:                                                             #
#      SOURCEDIR    location of install files                          #
#      DXVERSION    version of software in the install files           #
#      DXHOME       location in which to install software              #
#      DXPROD       name of product (for messages)                     #
#      UPGRADEDX    1 or 0, is this an upgrade?                        #
########################################################################
# test required environment set up
    zz=0
    for xx in SOURCEDIR DXVERSION DXHOME DXPROD UPGRADEDX DXMASTERKEYPASS; do
        yy="\$$xx"
        if [ -z "`eval echo ${yy}`" ]; then
        echo "ERROR Required parameter not set - $xx"
        zz=1
        fi
    done
    if [ $zz != 0 ]; then
        echo "Terminating - errors found"
        exit 1
    fi
    unset xx yy zz

########
# Main # 
########
main() 
{
    if [ $DOPREP -eq 1 ]; then
        stop_dsa_processes
        exit 0
    fi
    rm -Rf $DXHOME/bin* > /dev/null 2>&1
    rm -Rf $DXHOME/samples > /dev/null 2>&1

    install_dxserver
    add_user_env
    DXSRCBASH="source $DXHOME/.profile;"

    if [ -x $DXHOME/bin/dxcertgen ]; then
        if [ ! -f $DXHOME/config/dxEnc.conf ]; then
            if [ "$DXMASTERKEYPASS" = "defaultpass"  ]; then
                /bin/sh -c "$DXSRCBASH $DXHOME/bin/dxcertgen  masterkey"
            else
	        /bin/sh -c "$DXSRCBASH $DXHOME/bin/dxcertgen -W $DXMASTERKEYPASS masterkey"
            fi
        fi
    else
        echo "dxcertgen is not found"
    fi

    if [ $? != 0 ]
    then
        echo "ERROR - Occurred creating Masterkey file. Please run dxcertgen manually to generate MasterKey File"
    fi

    # remove_old_docs
    if [ $UPGRADEDX -eq 1 -a -d $DXHOME/docs ]; then
        rm -R $DXHOME/docs
    fi
}

install_dxserver()
{
    umask 027
    cd $DXHOME

    # Back-up any root CA certificate files
    if [ -f $DXHOME/config/ssld/trusted.pem ]; then
        mv $DXHOME/config/ssld/trusted.pem $DXHOME/config/ssld/trusted.pem.upgrade
    fi

    if expr $DXTAR : '.*\.tar\.Z$' >/dev/null
    then
        zcat $DXTAR | tar xf -
    elif expr $DXTAR : '.*\.tar\.gz$' >/dev/null
    then
        zcat $DXTAR | tar xf -
    else
        tar xf $DXTAR
    fi 
    if [ $? != 0 ]
    then
        echo "  ERROR - Load of $DXPROD product files failed"
        exit 1
    fi

    # Re-instate any backed up root CA certificate files
    if [ -f $DXHOME/config/ssld/trusted.pem.upgrade ]; then
        mv $DXHOME/config/ssld/trusted.pem.upgrade $DXHOME/config/ssld/trusted.pem
    fi

    # Ensure the the main samples.sh shell script is executable
    if [ -f $DXHOME/samples/samples.sh ]; then
        chmod a+x $DXHOME/samples/samples.sh >/dev/null 2>&1
    fi

    # Set DXHOME in ldap.conf file (used by OpenLDAP tool -Z option)
    if [ -f $DXHOME/config/ssld/dxldap.conf ]; then
        rm -fr $DXHOME/config/ssld/dxldap.conf.tmp
        cat $DXHOME/config/ssld/dxldap.conf | sed "s|__DXHOME__|$DXHOME|g" > \
	    $DXHOME/config/ssld/dxldap.conf.tmp
        mv $DXHOME/config/ssld/dxldap.conf.tmp $DXHOME/config/ssld/dxldap.conf
    fi
}

add_user_env()
{
    echo "  Setting up environment for account $DXUSER..."
    echo

    ###############
    # Bourne/Korn #
    ###############

    cat << EOF > $DXHOME/install/.dxprofile
umask 027
DXHOME=$DXHOME
PATH=\$DXHOME/bin:\${PATH}
$LIB_NAME=\$DXHOME/bin:\$$LIB_NAME
export DXHOME PATH $LIB_NAME
EOF
if [ $COPYCAPKI -eq 1 ]; then
    CAPKIPATH=`find $DXHOME/lib/capki -name "lib"`
    CAPKIPATH=`echo $CAPKIPATH`
    for CPATH in $CAPKIPATH;do
        cat << EOF >> $DXHOME/install/.dxprofile
        if [ -z "\$LD_LIBRARY_PATH" ]; then
                LD_LIBRARY_PATH=$CPATH
        else
                LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:$CPATH
        fi
EOF
    done
fi

##### Linux native threads
    if [ `uname` = "Linux" ]; then
        cat << EOF >> $DXHOME/install/.dxprofile

if [ -z "\$LD_LIBRARY_PATH" ]; then
    LD_LIBRARY_PATH=$JREHOME/lib/i386/native_threads
else
    LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:$JREHOME/lib/i386/native_threads
fi
export LD_LIBRARY_PATH
POSIXLY_CORRECT=1
export POSIXLY_CORRECT
EOF
    fi

##### AIX extended shared memory model
    if [ `uname` = "AIX" ]; then
        cat << EOF >> $DXHOME/install/.dxprofile

EXTSHM=ON
export EXTSHM
EOF
    fi

##### CASHCOMP
    cat << EOF >> $DXHOME/install/.dxprofile

# CA Shared Components
if [ -f /etc/profile.CA ]; then
    . /etc/profile.CA
    if [ ! -z \$CALIB ]; then
        LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:\${CALIB}
        export LD_LIBRARY_PATH
    fi
fi
EOF
if [ $COPYCAPKI -eq 1 ]; then
    cat << EOF >> $DXHOME/install/.dxprofile
CASHCOMP=$DXHOME/lib
CAPKIHOME=$DXHOME/lib/capki
export CASHCOMP CAPKIHOME
EOF
fi
 if [ -n "$JXPHOME" ]; then
        cat << EOF >> $DXHOME/install/.dxprofile

# JXplorer
    PATH=$JXPHOME:\${PATH}
EOF
    fi
##### previous DXwebserver install
    if [ -d $DXWEBHOME ]; then
        if [ -z "$JREHOME" ]; then
            cat << EOF >> $DXHOME/install/.dxprofile

# DXwebserver
DXWEBHOME=$DXWEBHOME
if [ "\`echo \$PATH | grep $DXWEBHOME\`" = "" ]; then
    PATH=$DXWEBHOME/bin:\${PATH}
fi
export DXWEBHOME PATH
EOF
        else
            cat << EOF >> $DXHOME/install/.dxprofile

# DXwebserver
DXWEBHOME=$DXWEBHOME
if [ "\`echo \$PATH | grep $DXWEBHOME\`" = "" ]; then
    PATH=$JREHOME/bin:$DXWEBHOME/bin:\${PATH}
fi
export DXWEBHOME PATH
EOF
        fi
    fi

    umask 027
	if [ ! -f $DXHOME/.profile ]; then
		echo ". $DXHOME/install/.dxprofile" > $DXHOME/.profile
	else
		# only source .dxprofile if it doesn't exist in .profile
		CHECK=`grep -l dxprofile $DXHOME/.profile`
		if [ ! -n "$CHECK" ]; then
			echo ". $DXHOME/install/.dxprofile" >> $DXHOME/.profile
		fi
	fi
	if [ -f $DXHOME/.bash_profile ]; then
		CHECK=`grep -l dxprofile $DXHOME/.bash_profile`
		if [ ! -n "$CHECK" ]; then
			echo ". $DXHOME/install/.dxprofile" >> $DXHOME/.bash_profile
		fi
	fi
    

if [ ! "x$DXUIHOME" = "x" ] && [ -d $DXUIHOME ]; then
    cat << EOF >> $DXHOME/install/.dxprofile

# Management UI
DXUIHOME=$DXUIHOME
if [ "\`echo \$PATH | grep $DXUIHOME\`" = "" ]; then
    PATH=$DXUIHOME:\${PATH}
fi
export DXUIHOME PATH
EOF

fi

    ###############
    # C shell     #
    ###############
    
    # create $DXHOME/install/.dxcshrc
    cat << EOF > $DXHOME/install/.dxcshrc
umask 027
setenv DXHOME $DXHOME
set path = ( \$DXHOME/bin \$path )
if ( ! \$?$LIB_NAME ) then
    setenv $LIB_NAME \$DXHOME/bin
else
    setenv $LIB_NAME \$DXHOME/bin:\${$LIB_NAME}
endif
set filec
EOF

if [ $COPYCAPKI -eq 1 ]; then
    CAPKIPATH=`find $DXHOME/lib/capki -name "lib"`
    CAPKIPATH=`echo $CAPKIPATH`
    for CPATH in $CAPKIPATH;do
        cat << EOF >> $DXHOME/install/.dxcshrc
        if !(\$?LD_LIBRARY_PATH) then
           setenv LD_LIBRARY_PATH $CPATH
        else
           setenv LD_LIBRARY_PATH \${LD_LIBRARY_PATH}:$CPATH
        endif
EOF
    done
cat << EOF >> $DXHOME/install/.dxcshrc
setenv CASHCOMP $DXHOME/lib
setenv CAPKIHOME $DXHOME/lib/capki
EOF
fi
##### Linux native threads
    if [ `uname` = "Linux" ] && [ -n "$JREHOME" ]; then
        cat << EOF >> $DXHOME/install/.dxcshrc

if !(\$?LD_LIBRARY_PATH) then
    setenv LD_LIBRARY_PATH ${JREHOME}/lib/i386/native_threads
else
    if ( "\`echo LD_LIBRARY_PATH | grep $JREHOME\`" == "" ) then
        setenv LD_LIBRARY_PATH \${LD_LIBRARY_PATH}:${JREHOME}/lib/i386/native_threads
    endif
endif
setenv POSIXLY_CORRECT 1
EOF
    fi

##### AIX extended shared memory model
    if [ `uname` = "AIX" ]; then
        cat << EOF >> $DXHOME/install/.dxcshrc

setenv EXTSHM ON
EOF
    fi

##### CASHCOMP
#    cat << EOF >> $DXHOME/install/.dxcshrc
#
## CA Shared Components
#if ( -e /etc/csh_login.CA ) then
#    source /etc/csh_login.CA
#    if ( \`env | grep CALIB\` == "" ) then
#        if ( \`env | grep LD_LIBRARY_PATH\` == "" ) then
#            setenv LD_LIBRARY_PATH \${CALIB}
#        else
#            setenv LD_LIBRARY_PATH \${LD_LIBRARY_PATH}:\${CALIB}
#        endif
#    endif
#endif
#umask 027 # because csh_login.CA unsets this
#EOF

        if [ -n "$JXPHOME" ]; then
        cat << EOF >> $DXHOME/install/.dxcshrc

# JXplorer
    set path = ( $JXPHOME \$path )
EOF
    fi
    
##### previous DXwebserver install
    if [ -d $DXWEBHOME ]; then
        if [ -z "$JREHOME" ]; then
            cat << EOF >> $DXHOME/install/.dxcshrc

# DXwebserver
setenv DXWEBHOME $DXWEBHOME
if ( "\`echo \$PATH | grep $DXWEBHOME\`" == "" ) then
    set path = ( $DXWEBHOME/bin \$path )
endif
EOF
        else
            cat << EOF >> $DXHOME/install/.dxcshrc

# DXwebserver
setenv DXWEBHOME $DXWEBHOME
if ( "\`echo \$PATH | grep $DXWEBHOME\`" == "" ) then
    set path = ( $JREHOME/bin $DXWEBHOME/bin \$path )
endif
EOF
        fi
    fi

    umask 027
    if [ ! -f $DXHOME/.cshrc ]; then
        echo "source $DXHOME/install/.dxcshrc" > $DXHOME/.cshrc
    else
        # only source .dxcshrc if it doesn't exist in .cshrc
        CHECK=`grep -l dxcshrc $DXHOME/.cshrc`
        if [ ! -n "$CHECK" ]; then
            echo "source $DXHOME/install/.dxcshrc" >> $DXHOME/.cshrc
        fi
    fi

if [ ! -z $DXUIHOME ] && [ -d $DXUIHOME ]; then
    cat << EOF >> $DXHOME/install/.dxcshrc

# Management UI
if ( "\`echo \$PATH | grep $DXUIHOME\`" == "" ) then
    set path = ( $DXUIHOME \$path )
endif
setenv DXUIHOME $DXUIHOME

EOF

fi

}

stop_dsa_processes()
{
    echo
    echo "  Stopping any existing DXservers, SSL daemons or DXadmind processes"

    # add DXHOME/bin to root's LIB_NAME to run OpenSSL libs
    # add II_SYSTEM/ingres/lib for old 4.1 dxadmind
    case $LIB_NAME in
        "LD_LIBRARY_PATH" ) LD_LIBRARY_PATH=$DXHOME/bin
                            if [ -n "II_SYSTEM" ]; then 
                                LD_LIBRARY_PATH=$II_SYSTEM/ingres/lib:$LD_LIBRARY_PATH 
                            fi
                            export LD_LIBRARY_PATH
                            ;;
        "LIBPATH" )         LIBPATH=$DXHOME/bin
                            if [ -n "II_SYSTEM" ]; then 
                                LIB_PATH=$II_SYSTEM/ingres/lib:$LIB_PATH 
                            fi
                            export LIBPATH
                            ;;
        "SHLIB_PATH" )      SHLIB_PATH=$DXHOME/bin
                            if [ -n "II_SYSTEM" ]; then 
                                SHLIB_PATH=$II_SYSTEM/ingres/lib:$SHLIB_PATH 
                            fi
                            export SHLIB_PATH
                            ;;
    esac

    if [ -x $DXHOME/bin/ssld ]; then # note: ssld won't exist after the upgrade
        echo
        $DXHOME/bin/ssld stop all
        if [ -n "`ps -e | grep ssld | grep $DXUSER | grep -v grep`" ]; then
            echo
            echo "  There are ssld processes running that the install cannot stop."
            echo "  Please stop these manually before re-running the install."
            echo
            exit 1
        fi
    fi

    if [ -d $DXHOME/config/tlsclient ]; then
        echo
        $DXHOME/bin/tlsclient stop all
        if [ -n "`ps -e | grep tlsclient | grep $DXUSER | grep -v grep`" ]; then
            echo
            echo "  There are tlsclient processes running that the install cannot stop."
            echo "  Please stop these manually before re-running the install."
            echo
            exit 1
        fi
    fi

    if [ -x $DXHOME/bin/dxadmind ]; then
        echo
        $DXHOME/bin/dxadmind stop all
        if [ -n "`ps -e | grep dxadmind | grep $DXUSER | grep -v grep`" ]; then
            echo
            echo "  There are dxadmind processes running that the install cannot stop."
            echo "  Please stop these manually before re-running the install."
            echo
            exit 1
        fi
    fi

    if [ -x $DXHOME/bin/dxserver ]; then
        echo
        $DXHOME/bin/dxserver stop all

        CUR_MAJOR=`echo $CUR_VERSION |awk -F. '{print $1}' `
        if [ $CUR_MAJOR -lt 8 ]; then
            # pre 8.0, a dxserver stop did not wait until the server had actually
            # stopped before returning control, so the following 'ps' would fail
            # because the process hadn't actually ended. Task 8278.
            echo "  sleep 30..."
            echo "  (pre-r8 versions of dxserver do not wait until all DSAs are stopped)."
            sleep 30
        fi
        if [ -n "`ps -e | grep dxserver | grep $DXUSER | grep -v grep`" ]; then
            echo
            echo "  There are dxserver processes running that the install cannot stop."
            echo "  Please stop these manually before re-running the install."
            echo
            exit 1
        fi
    fi
}


############ Invoke mainline ############
if [ -n "$1" ]; then
    DOPREP=1
else
    DOPREP=0
fi

main
