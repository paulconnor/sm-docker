#!/bin/sh 
# Computer Associates DXserver Setup Script 
# $Id: dxsetup.sh,v 1.263 2015/05/18 04:22:28 dmytry Exp $
################################################################################
#              DXserver Installation Behaviour                                 #
################################################################################
# dxsetup.sh lets you select between Express Install and Custom Install        #
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
# DXserver Install:                                                            #
#                                                                              #
#   - Create the DXserver administration account if it doesn't already exist.  #
#   - Select the installation location in which to install DXserver.           #
#   - Install DXserver in the specified location as the administrator.         #
#                                                                              #
################################################################################

#################################
# Setting Variables for install #
#################################
#TMPINSTALLFILE=/tmp/dxinst.$$              # working temporary file for dxsetup
TMPINSTALLFILE=/opt/CA/Directory/dxserver/dxinst.$$              # working temporary file for dxsetup
PROGNAME=DXsetup                          # Program Name
LICENSE_FILE=ca_license.txt               # The name of the license file
SHOW_LICENCE=0                            # Used to show End User License 
INSTUSER=root                             # must run install as this user

DXSIZE=200                                # DXserver Size
DOCSIZE=17                                # Size of documentation 

NODOCS=1                                  # Defining NoDocs switch variable
DEFANS=0                                  # Defining Default switch variable
DXGRIDSIZE=0                              # This is just so DXGRIDSIZE is initialised. 
SOURCEDIR=`pwd`                           # Declaring the Sourcedir variable
VERSION_FILE=osversion.txt                # file to use for OS version checking
RESPONSE_FILE=$SOURCEDIR/responsefile.txt # install defaults 
DAT=`date +%Y%m%d%H%M%S`                  # installation logging 
INSTALL_LOG_NAME=cadir_install_        
INSTALL_LOG_NAME=${INSTALL_LOG_NAME}${DAT}
INSTALL_LOG_NAME=${INSTALL_LOG_NAME}.log
#NOUPGRADEBLD=2133
NOUPGRADEBLD=-1
RESTOREERROR=0
CADIR_R120SP1=2112

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
    test_for_tar_files                    # tests for the install tar files 

    get_dxuser dxsetup                    # checks for existing DXUSER
    set_home_dirs                         # set the installed directories
    set_upgrade_variables                 # find out what is installed
    setup_write_response_file             # set up a responsefile

    find_previous_versions                # check if we need to upgrade
    initial_screens                       # License Agreement and Welcome screens.
    display_previous_versions

    check_defans                          # parameters for default install
    dxserver_questions                    # questions for the DXserver install
    capki_questions                       # questions for the CAPKI install
    if [ `uname` = "Linux" ]; then
        dxagent_questions                 # questions for the DXagent install
    else
        INSTALLDXAGENT=n
    fi

    write_response_file                   # create a responsefile
    check_install_required                # check if anything being installed
    test_for_write_permissions            # check that dir owners (dsa, ingres) have write access 
    load_upgrade_defaults                 # handle response file upgrades
    run_dxserver_install                  # run the DXserver Install
    dxagent_check_cadir_version
    run_dxagent_install                   # installs DXagent 
if [ $NONROOTUSER -eq 0 ]; then
    start_at_boot                         # sets up the reboot scripts
fi
    installation_complete                 # displays Installation Complete message
    relocate_log                          # copy log file to base directory
    show_readme                           # display readme at the end of install
    if [ "$TMPSOURCEDIR" != "" ]; then    # remove temporary source directory, if set
        rm -rf $TMPSOURCEDIR
    fi
}
################################################################################
################################################################################



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
				echo "  should be a few levels down from the '/' directory." 	| $LOG
				echo "  Please re-enter." 										| $LOG
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
			echo " before continuing " 											| $LOG
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
    echo "    ./dxsetup.sh -responsefile $WRITE_RESPONSE_FILE"       | $LOG
    echo | $LOG
    
    exit 0
}

check_install_required()
{
    MSG=1
    if [ "$INSTALLDX"  = "y" -o $SKIPDX -eq 1 ]; then MSG=0
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

##############################
# Installation Complete Sign #
##############################
installation_complete()
{
    echo | $LOG
    echo "============================ INSTALLATION COMPLETE ============================" | $LOG
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

    if [ -d $DXHOME ]; then
        chgrp -R $DXGROUP $DXHOME | $LOG
        chmod -R o= $DXHOME | $LOG
        chown $DXUSER $DXHOME/logs/*.* | $LOG  
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

    RELNOTE_BLD=0
    if [ -f relnotes ]; then
        RELNOTE_BLD=`cat -v relnotes | egrep 'Update|Build' | awk 'NR==1 {print $NF}'`
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

    chgrp $DXGROUP readme readme.html relnotes | $LOG
    chown $DXUSER readme readme.html relnotes | $LOG  

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
echo "dxsetup" >> $INSTALL_LOG
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


