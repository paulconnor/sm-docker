#!/bin/sh 
# Computer Associates DXserver Uninstall Script 
# $ID: dxuninst.sh, v 4.18 2002/03/14 04:30:00 travis Exp $
#

trap checkpoint HUP INT TERM

############################################
# Installation variables - set as required #
############################################

INSTUSER=root                   # user that runs uninstall
NUM=1                           # menu system numbers
PROGNAME="DXserver Uninstall"
DXUSER=$DXUSER

UNINSTALLDX=0                   # are we uninstalling DXserver
UNINSTALLDXA=0                  # are we uninstalling DXagent
UNINSTALLDXW=0                  # are we uninstalling DXwebserver
UNINSTALLUI=0                   # are we uninstalling Management UI
EMBEDDED=0                      # is this an embedded install
DELDXUSER=0                     # remove DXUSER

DXINST=0                        # do we have a DXserver install
DXAINST=0                        # do we have a DXserver install
DXUIINST=0                      # do we have a Management UI install
INGINST=0                       # do we have an Ingres install
DXWEBSERVERINST=0               # do we have a DXwebserver install

DEFANS=0                        # used for -silent install
EXITCODE=0                      # allow for different success values

######################################
# Main section of script starts here #
######################################
main()
{
    while [ $# -gt 0 ]; do 
        arg=$1
        shift

        if [ $arg = "-list" ]; then
            display_list
        elif [ $arg = "-dxserver" ]; then
            UNINSTALLDX=1
        elif [ $arg = "-dxmgmtui" ]; then
            UNINSTALLUI=1
        elif [ $arg = "-dxagent" ]; then
            UNINSTALLDXA=1
        elif [ $arg = "-all" ]; then
            UNINSTALLDX=1
            UNINSTALLDXA=1
            UNINSTALLUI=1
            DELDXUSER=1
        elif [ $arg = "-silent" ]; then
            DEFANS=1
            UNINSTALLDX=1
            UNINSTALLDXA=1
            UNINSTALLUI=1
            DELDXUSER=1
    	elif [ $arg = "-dxuser" ]; then
	        if [ $# -gt 0 ]; then
	                if [ "`echo $1 | cut -c 1`" != "-" ]; then
	                    DXUSER=$1
	                    if [ -z "$DXUSER" ] || [ "$DXUSER" = "" ]; then
	                        echo "  -dxuser must not be blank"
	                        echo "  Installation terminated."
	                        exit 1
	                    fi
	                    shift
	                    continue
	                fi
	            fi
	            echo "  You must provide an argument to -dxuser."
	            echo "  Uninstall terminated."
	            exit 1
        elif [ $arg = "-r" ]; then
            if [ $# -gt 0 ]; then
                if [ "`echo $1 | cut -c 1`" != "-" ]; then
                    SOURCEDIR=$1
                    if [ -z "$SOURCEDIR" ] || [ "$SOURCEDIR" = "" ]; then
                        echo "  -r must not be blank"
                        echo "  Installation terminated."
                        exit 1
                    fi
                    shift
                    continue
                fi
            fi
            echo "  You must provide an argument to -r."
            echo "  Uninstall terminated."
            exit 1
        fi
        
        if [ -z "$DXUSER" ]; then
        	DXUSER="dsa"
        fi
    done

    if [ -z "$SOURCEDIR" ]; then
        SOURCEDIR=`pwd`
    fi
    if [ ! -d $SOURCEDIR ]; then
        echo
        echo "$SOURCEDIR is not a directory"
        quit_program
    fi
    export SOURCEDIR  

############################
#    Calling  Functions    #
############################

    source_shared_file          # Sources the correct file 
    user_verify                 # Verify if correct user 
    get_dxuser                  # Gets DXUSER
    set_home_dirs               # Sets the DXserver,Ingres home dirs
    whats_installed             # Finds out which programs are installed

    if [ $UNINSTALLDX -eq 0 -a $UNINSTALLDXA -eq 0 -a $UNINSTALLUI -eq 0 ]; then
        menu                    # Menu options for uninstall.
    fi
    check_dependencies          # Supporting products, DXUSER, etc

    # check that we are actually uninstalling something
    MSG=1
    if [ $DXINST -eq 1 -a $UNINSTALLDX -eq 1 ]; then MSG=0
    elif [ $DXUIINST -eq 1 -a $UNINSTALLUI -eq 1 ] ; then MSG=0
    elif [ $DXAINST -eq 1 -a $UNINSTALLDXA -eq 1 ] ; then MSG=0
    fi
    if [ $MSG -eq 1 ]; then
        echo
        echo "No products to uninstall." 
        quit_program
    fi

    uninstall_dxagent           # uninstall DXagent
    uninstall_dxmgmtui          # uninstall Management UI
    uninstall_dxserver          # uninstall DXserver 
    if [ -n "$JXPHOME" ]; then
    	uninstall_jxplorer
    fi
    if [ $NONROOTUSER -eq 0 ]; then
        remove_reboot               # Whether or not it removes the reboot scripts.
        uninstall_caopenssl               # Works out whether or not to remove the DXUSER
    fi
    remove_dxuser
    check_empty_install_dir     # Check to see if the install directory is empty
    uninstall_complete          # Shows exit screen.
}

###############################
#       FUNCTIONS             #
###############################
menu()
{
    if [ -z "$DX" ]; then DX=" "; fi
    if [ -z "$DXA" ]; then DXA=" "; fi
    if [ -z "$DXM" ]; then DXM=" "; fi
    if [ -z "$DXU" ]; then DXU=" "; fi
    SUP=0
    clear
    greeting

    echo
    echo "The following $PRODNAME components are installed."
    echo
    if [ "$DXINST" -eq 1 ]; then
        echo "$NUM. [ $DX ] $DXPROD"
        DXNUM=$NUM
        NUM=`expr $NUM + 1 `
    fi

    if [ "$DXAINST" -eq 1 ]; then
        echo "$NUM. [ $DXA ] $DXAGENTPROD"
        DXANUM=$NUM
        NUM=`expr $NUM + 1 `
    fi

    if [ "$DXUIINST" -eq 1 ]; then
        echo "$NUM. [ $DXM ] $DXMGMTUIPROD"
        DXMNUM=$NUM
        NUM=`expr $NUM + 1 `
    fi

    if [ "$DXWEBSERVERINST" -eq 1 ]; then
        echo "         $DXWEBSERVERPROD             supporting product - not removed"
        SUP=1
    fi

    if [ "$DXINST" -eq 1 -o "$DXUIINST" -eq 1  -o "$DXAINST" -eq 1 ]; then
        if [ $SUP -eq 1 ]; then
            echo "         $DXPROD account  ($DXUSER) can only be removed if all components selected"
        else
            echo "$NUM. [ $DXU ] $DXPROD account  ($DXUSER) can only be removed if all components selected"
            DXUSERNUM=$NUM
            NUM=`expr $NUM + 1 `
        fi
    fi

    NUM=1 # Reset the number.
    echo
    echo "Please select the required components to uninstall."
    echo
    echo "Note: Additional Options"
    echo "\`more' for a list of available commands."
    echo "\`help' information on how to use the commands"
    echo "\`quit' to exit the uninstall program"
    echo "\`go'   to uninstall the products selected"
    QUESTION="Please select an option."
    DEFAULT="all"
    get_response

    echo $RETURN |grep -i 'advanced' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        RETURN=xAdvanced  # need the x to differentiate between advanced and advantage (6071)
    fi
    echo $RETURN |grep -i '^dxs' > /dev/null 2>&1
    if [ $? -eq 0 ]; then 
        RETURN=$DXNUM
        echo $RETURN
    fi
    echo $RETURN |grep -i '^q' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        RETURN=quit
    fi

    case $RETURN in
        "more") 
            clear
            echo
            echo "The following options are available:"
            echo "    Advanced        Gives more information on the products selected"
            echo "    Quit            Exits the program."
            echo "    All             Selects all components installed."
            echo "    ProgramName     Selects the program name from the list."
            echo "    ProgramNumber   Selects the Program that corresponds to the menu number"
            echo "    Go              Uninstalls the components that are selected."
            echo
            get_response cont
            menu
            ;;
        "help")
            help
            ;;
        "$DXNUM")
            if [ "$DX" = "x" ]; then
                DX=" "
                DXU=" "
            else
                DX="x"
            fi
            menu
            ;;
        "$DXANUM")
            if [ "$DXA" = "x" ]; then
                DXA=" "
                DXU=" "
            else
                DXA="x"
            fi
            menu
            ;;
        "$DXMNUM")
            if [ "$DXM" = "x" ]; then
                DXM=" "
                DXU=" "
            else
                DXM="x"
            fi
            menu
            ;;
        "$DXUSERNUM")
            if [ "$DXU" = "x" ]; then
                DXU=" "
            else
                DXU="x"
            fi
            check_dependencies
            menu
            ;;
        "all")
            if [ "$DX" = "x" -o "$DXM" = "x" -o "$DXA" = "x" -o "$DXU" = "x" ]; then
                DX=" "
                DXM=" "
                DXA=" "
                DXU=" "
            else
                DX="x"
                DXM="x"
                DXA="x"
                DXU="x"
                check_dependencies
            fi 
            menu
            ;;
        "go")
           if [ "$DX" = " " -a "$DXM" = " " -a "$DXA" = " " -a "$DXU" = " " ]; then
               echo
               echo "Please select a product to uninstall"
               get_response cont
               menu
           fi

           clear

           echo
           echo "The following products have been selected to be uninstalled:"
           if [ "$DX" = "x" -a "$DXINST" -eq 1 ]; then
               echo "  $DXPROD"
               UNINSTALLDX=1
           fi
           if [ "$DXA" = "x" -a "$DXAINST" -eq 1 ]; then
               echo "  $DXAGENTPROD"
               UNINSTALLDXA=1
           fi
           if [ "$DXM" = "x" -a "$DXUIINST" -eq 1 ]; then
               echo "  $DXMGMTUIPROD"
               UNINSTALLUI=1
           fi
           if [ "$DXU" = "x" ] && [ "$DXINST" -eq 1 -o "$DXAINST" -eq 1 -o "$DXUIINST" -eq 1 ]; then
               echo "  $DXPROD account ('$DXUSER')"
               DELDXUSER=1
           fi

           QUESTION="Are you sure you would like to remove these components? (y/n)"
           DEFAULT="n"
           get_response ynq
          
           if [ "$RETURN" = "n" ]; then
               menu
           fi
           ;; 
        "quit")
           quit_program
           ;;
        "xAdvanced")
           clear
           advanced_screens
           menu
           ;;
        *) help
           ;;
    esac
}

check_dependencies()
{
    if [ "$DXINST" -eq 1 -a "$DX" = " " ] || \
       [ "$DXAINST" -eq 1 -a "$DXA" = " " ] || \
       [ "$DXUIINST" -eq 1 -a "$DXM" = " " ] || \
       [ "$DXWEBSERVERINST" -eq 1 ]; then
            DXU=" "
            DELDXUSER=0
    fi

}

help()
{
    clear
    echo
    echo "      ------------------------- HELP ---------------------------"
    echo "       To select a product you can either type the product name "
    echo "       or select the number that corresponds to the product."
    echo
    echo "              EXAMPLE:     1. [  ] DXserver"
    echo
    echo "       This example you can type the number '1' or 'DXserver'"
    echo
    echo "       NOTE: -  The product name is not case sensitive."
    echo "             -  Repeated commands will unselect what was selected."
    echo "             -  The first 3 letters are significant, "
    echo "                ie, 'dxs' will select DXserver"
    echo "             -  To uninstall the selected products type 'go'."
    echo "      ----------------------------------------------------------"
    get_response cont
    menu
}

################
# quit_program #
################
quit_program()
{
    echo
    echo "  Uninstall terminated."
    exit 1
}

####################
# display greeting #
####################
greeting()
{
    echo "---------------------------------------------------------------------------"
    echo "                     $PRODNAME Uninstall Script"
    echo ""
    echo "                Copyright 2020 CA. All rights reserved."
    echo "---------------------------------------------------------------------------"
}

############################################
# load library routines from dxsetup.shlib #
############################################
source_shared_file()
{
    if [ -r $SOURCEDIR/dxsetup.shlib ]; then
        . $SOURCEDIR/dxsetup.shlib
    else
        echo
        echo "  Can't find library of script functions"
        quit_program
    fi
    if [ -r $SOURCEDIR/dxprepare.shlib ]; then
        . $SOURCEDIR/dxprepare.shlib
    else
        echo
        echo "  Can't find library of script functions"
        quit_program
    fi

    case `uname` in
       "HP-UX" )
                if [ -r $SOURCEDIR/dxsetuphpux.shlib ]; then
                    . $SOURCEDIR/dxsetuphpux.shlib
                fi
              ;;

       "SunOS" )
                if [ -r $SOURCEDIR/dxsetupsolaris.shlib ]; then
                    . $SOURCEDIR/dxsetupsolaris.shlib
                fi
              ;;

       "AIX"   )
                if [ -r $SOURCEDIR/dxsetupaix.shlib ]; then
                    . $SOURCEDIR/dxsetupaix.shlib
                fi
              ;;

       "Linux" )
                if [ -r $SOURCEDIR/dxsetuplinux.shlib ]; then
                    . $SOURCEDIR/dxsetuplinux.shlib
                fi
              ;;
 
              *)
                echo
                echo "Can't find shared library files"
                quit_program
              ;;
    esac
}

##########################
# shall we remove DXUSER #
##########################
remove_dxuser()
{
    REMOVE_DXUSER=1

    if [ $DELDXUSER -eq 0 -o $NONROOTUSER -eq 1 ]; then
        REMOVE_DXUSER=0
    fi
    if [ -n "$DXHOME" ] && [ -d $DXHOME/dxagent -o -d $DXHOME/bin -o -h $DXHOME/bin ]; then
        # need to check bin, because DXHOME may still be there
        REMOVE_DXUSER=0
    elif [ -n "$DXUIHOME" ] && [ -d $DXUIHOME -o -h $DXUIHOME ]; then
        REMOVE_DXUSER=0
    elif [ -n "$DXWEBHOME" ] && [ -d $DXWEBHOME -o -h $DXWEBHOME ]; then
        REMOVE_DXUSER=0
    fi

    if [ -n "$DXHOME" ] && [ "$DXINST" -eq 0 ] && [ -d $DXHOME ]; then
        # we can now remove the rest of DXHOME unless we are retaining the
        # DSA user
        if [ $REMOVE_DXUSER -eq 1 ]; then
            delete_user_dxserver

            # we can now remove the rest of DXHOME
            rm -fr $DXHOME
        else
            # we are retaining DXwebserver and the dsa user redirect profile
            if [ -n "$DXWEBHOME" ] && [ "$DXWEBSERVERINST" -eq 1 ]; then
		cd $DXWEBHOME
                rm -fr $DXHOME # clear old contents
            else
                if [ $NONROOTUSER -eq 1 ]; then
                    cd $HOME
                else
                    cd $DXHOME
                fi
                # need adjust login scripts to remove reference to DXHOME and
                # remove the rest of the files
                if [ -f ".cshrc" ]; then
                    cat .cshrc | grep -v "$DXHOME" > /tmp/DXcshrc
                fi
                if [ -f ".profile" ]; then
                    cat .profile | grep -v "$DXHOME" > /tmp/DXprofile
                fi
                if [ -f ".bash_profile" ]; then
                    cat .bash_profile | grep -v "$DXHOME" > /tmp/DXbash_profile
                fi
                if [ $NONROOTUSER -eq 0 ]; then
                    rm -fr * # clear contents only for root user ("dsa") uninstallation
                fi
                if [ -f "/tmp/DXcshrc" ]; then
                    cp /tmp/DXcshrc .cshrc
                fi
                if [ -f "/tmp/DXprofile" ]; then
                    cp /tmp/DXprofile .profile
                fi
                if [ -f "/tmp/DXbash_profile" ]; then
                    cp /tmp/DXbash_profile .bash_profile
                fi
            fi
        fi

        cd `dirname $DXHOME`
        rm -f readme*
        rm -f relnotes*
    fi

    # 13582, 13592,13594 : need to make sure that we only change to
    # dxwebserver home if we uninstall dxserver
    if [ $UNINSTALLDX -eq 1 ] && [ -n "$DXWEBHOME" ] && [ -d $DXWEBHOME -o -h $DXWEBHOME ]; then
        dxusermod $DXWEBHOME $DXUSER 
    fi
}

######################
# Uninstall DXserver #
######################
uninstall_dxserver()
{
    if [ "$DXINST" -eq 0 ] ; then
        return
    fi
    if [ $UNINSTALLDX -eq 0 ]; then
        return
    fi

    echo
    echo "-------------------- DXserver Uninstall ---------------------"

    # don't uninstall if dxserver databases exist
    check_dxserver_databases    
    if [ $UNINSTALLDX -eq 0 ]; then
        return
    fi

    BACKUPCONFIG="n"

    if [ $DEFANS -eq 0 ]; then
        while [ $BACKUPCONFIG = "n" ]; do
            QUESTION="  Do you want to take a backup of your config directory? (y/n)"
            DEFAULT="n"
            get_response ynq
            BACKUPCONFIG=$RETURN
            if  [ $BACKUPCONFIG = "n" ]; then
                break
            else
            	RETURN="n"
            	while [ $RETURN = "n" ]; do
                        if [ $NONROOTUSER -eq 0 ]; then
	                      DXVERSION=`su - $DXUSER -c "$DXSRCBASH $DXHOME/bin/dxserver version" | tr -d ')'|grep dxserver|awk -F' ' '{print $2 "." $4}' `
                        else
	                      DXVERSION=`$DXHOME/bin/dxserver version | tr -d ')'|grep dxserver|awk -F' ' '{print $2 "." $4}' `
                        fi
	                echo
	                echo "  Please specify a backup directory (do NOT use /tmp):"
	                QUESTION=""
	                DEFAULT1=`dirname $DXHOME`
	                DEFAULT=`dirname $DEFAULT1`/caDir_config.$DXVERSION
	                get_response path
	                GETDIR=$RETURN
	                PROD="backup"
	                check_product_dir
	            done
            fi
        done
        CONFIGDIR=$GETDIR
        BACKUPGRIDFILES="n"
       #Labtrack 13153: grid files need to be left during an uninstall. If grid files are not under DXHOME we dont delete.
        while [ $BACKUPGRIDFILES = "n" ]; do
	        	QUESTION="  Do you want to take a backup of your existing datastore files? (y/n)"
	            DEFAULT="n"
	            get_response ynq
	            BACKUPGRIDFILES=$RETURN
	            
	            if  [ $BACKUPGRIDFILES = "n" ]; then
	                break
	            else
	            	RETURN="n"
	            	while [ $RETURN = "n" ]; do
                                if [ $NONROOTUSER -eq 0 ]; then
                     	                DXVERSION=`su - $DXUSER -c "$DXSRCBASH $DXHOME/bin/dxserver version" | tr -d ')'|grep dxserver|awk -F' ' '{print $2 "." $4}' `
                                else
                     	                DXVERSION=`$DXHOME/bin/dxserver version | tr -d ')'|grep dxserver|awk -F' ' '{print $2 "." $4}' `
                                fi
		                echo
		                echo "  Please specify a backup directory (do NOT use /tmp):"
		                QUESTION=""
		                DEFAULT1=`dirname $DXHOME`
		                DEFAULT=`dirname $DEFAULT1`/caDir_data.$DXVERSION
		                get_response path
		                GETDIR=$RETURN
		                PROD="backup"
		                check_product_dir
	                done
	            fi
        done
        GRIDFILEDIR=$GETDIR
        if [ $BACKUPCONFIG = "y" ]; then
            echo "  Copying config into $CONFIGDIR"
            mkdir -p $CONFIGDIR
            cp -rp $DXHOME/config/* $CONFIGDIR
        fi
    	if [ $BACKUPGRIDFILES = "y" ]; then
            echo "  Copying datastores into $GRIDFILEDIR"
            mkdir -p $GRIDFILEDIR
            cd $DXHOME/config/servers
            if [ $NONROOTUSER -eq 0 ]; then
                 DSAS=`su - $DXUSER -c "$DXSRCBASH dxserver status" | grep stopped | awk '{print $1}'`
            else
                 DSAS=`$DXSRCBASH dxserver status | grep stopped | awk '{print $1}'`
            fi
            for DSA in $DSAS; do
                GRIDLOCATION=`$DXHOME/bin/dxupgradecheck -dxgridloc $DSA 2>/dev/null`
                if [ -d "$GRIDLOCATION" ]; then
                    mv -f $GRIDLOCATION/$DSA.* $GRIDFILEDIR
                fi
            done
        fi
    fi
	
	USERHOMEDIR=`dxpasswdtool getuserhomedir $DXUSER`
	export USERHOMEDIR
    echo
    echo "Stopping all existing DXserver processes"
    if [ $NONROOTUSER -eq 0 ]; then
        su - $DXUSER -c "$DXSRCBASH dxserver stop all"
        if [ -f $DXHOME/bin/dxadmind ]; then su - $DXUSER -c "$DXSRCBASH dxadmind stop all; dxadmind remove all"; fi
    else
		/bin/sh -c "$DXSRCSH; dxserver stop all"
        if [ -f $DXHOME/bin/dxadmind ]; then /bin/sh -c "$DXSRCBASH dxadmind stop all; dxadmind remove all"; fi
    fi

    if [ -d $DXHOME/config/tlsclient ]; then
        if [ $NONROOTUSER -eq 0 ]; then
              su - $DXUSER -c "$DXSRCBASH \
                         tlsclient stop all; tlsclient remove all"
        else
                         `tlsclient stop all; tlsclient remove all`
             
        fi
    fi

    if [ -n "`ps -e | grep dxserver | grep -v grep`" ]; then
        echo
        echo "DXserver jobs are still running"
        echo "Please stop them before re-running the uninstall"
        quit_program
    fi
	
	#13880 - lic98 is no longer apart of CA Directory. 
    # manually stop the lic98fds process
    #if [ -x $CASHCOMP/ca_lic/stopfds ]; then
    #    echo "Stopping Lic98"
    #    ( $CASHCOMP/ca_lic/stopfds )
    #    sleep 3
    #fi

    echo "Removing the $DXPROD installation"
    cd $DXHOME

    # must keep DXHOME and .profile/.cshrc if we're keeping DXUSER.
    # Because we don't  know this yet, keep it anyway, and remove it later.
    # Need to keep the install directory too.
    for DIR in `ls | grep -v "^install" | grep -v "dxagent"`; do
        rm -fr $DIR
    done

    echo
    echo "$DXPROD installation removed"
    DXINST=0
}

#####################
# Uninstall DXagent #
#####################
uninstall_dxagent()
{
    if [ "$DXAINST" -eq 0 ] ; then
        return
    fi
    if [ $UNINSTALLDXA -eq 0 ]; then
        return
    fi

    echo
    echo "-------------------- $DXAGENTPROD Uninstall ---------------------"

    if [ $NONROOTUSER -eq 0 ]; then
         su - $DXUSER -c "$DXSRCBASH \
                     cd $DXHOME/dxagent; ./stop_dxagent.sh"
    else
		/bin/sh -c "$DXSRCSH; \
                     cd $DXHOME/dxagent; ./stop_dxagent.sh"
    fi

    cd $DXHOME
    rm -fr $DXHOME/dxagent
    echo
    echo "$DXAGENTPROD successfully removed"
}

###########################
# Uninstall Management UI #
###########################
uninstall_dxmgmtui()
{
    if [ "$DXUIINST" -eq 0 ] ; then
        return
    fi
    if [ $UNINSTALLUI -eq 0 ]; then
        return
    fi

    echo
    echo "-------------------- $DXMGMTUIPROD Uninstall ---------------------"

    LOCAL_DSA_NAME=$(hostname)-management-ui
    LOCAL_MONITORING_DSA_NAME=$(hostname)-monitoring-management-ui
    if [ $NONROOTUSER -eq 0 ]; then
         su - $DXUSER -c "$DXSRCBASH \
                     cd $DXUIHOME; ./dxscimserver stop; ./dxmgmtuiserver stop"
    else
		/bin/sh -c "$DXSRCBASH \
                     cd $DXUIHOME; ./dxscimserver stop; ./dxmgmtuiserver stop"
    fi

    cd `dirname $DXUIHOME`
    rm -fr $DXUIHOME
    echo
    echo "$DXMGMTUIPROD successfully removed"

    echo
    echo "Stopping Management UI embedded DSAs"
    echo
    if [ $NONROOTUSER -eq 0 ]; then
         su - $DXUSER -c "$DXSRCBASH \
					 dxserver stop $LOCAL_DSA_NAME; dxserver stop $LOCAL_MONITORING_DSA_NAME"
    else
		/bin/sh -c "$DXSRCBASH \
					 dxserver stop $LOCAL_DSA_NAME; dxserver stop $LOCAL_MONITORING_DSA_NAME"
    fi

}


######################
# Uninstall JXplorer #
######################
uninstall_jxplorer()
{
    echo
    echo "-------------------- JXplorer Uninstall ---------------------"

    # Remove from Reference Count file. If no rows left then continue uninstall
    REF_COUNT=0
    if [ -f $JXPHOME/.reference_count ]; then
        cat $JXPHOME/.reference_count | grep -v "$MATCH" > $JXPHOME/.reference_count_tmp
        mv $JXPHOME/.reference_count_tmp $JXPHOME/.reference_count
        REF_COUNT=`cat $JXPHOME/.reference_count | wc -l | tr -d " "`
    fi
    if [ $REF_COUNT -gt 0 ]; then
        # still required
        return
    else
        # No longer required as empty
        if [ -f $JXPHOME/.reference_count ]; then
            rm $JXPHOME/.reference_count
        fi
    fi

    echo 
    echo "Removing the JXplorer installation" 
    # Find where the link points
    cd $JXPHOME
    CURRENTPWD=`$OSPWD`
    cd ..

    # Remove the JXplorer installation
    rm -fr $CURRENTPWD

    # Remove the symbolic link
    if [ ! -z "$SYMBOLIC_JXPHOME" ]; then
        rm -f $SYMBOLIC_JXPHOME
    fi
}

################################
# check for dxserver databases #
################################
check_dxserver_databases()
{
	
	#13431: need to halt the install if there are dxservers running unless its our democorp or unspsc samples" 
	
	if [ $DXINST -eq 1 ]; then 
		DSALIST=""
                if [ $NONROOTUSER -eq 0 ]; then
		     DSALIST=`su - $DXUSER -c "$DXSRCBASH dxserver status" | grep "started" | awk '{print $1}' | egrep -v '^router|^democorp$|^unspsc$|^test$' `
                else
		     DSALIST=`dxserver status | grep "started" | awk '{print $1}' | egrep -v '^router|^democorp$|^unspsc$|^test$' `
                fi
		if [ -n "$DSALIST" ]; then
			echo 
			echo "The following $DXPROD services are still running: "
			echo "$DSALIST"
			echo  
			echo "You will need to stop these services before proceeding "
			echo "with the $DXPROD uninstall "
			UNINSTALLDX=0
        	EXITCODE=2 # 9067: if exiting with this status, pkgadd will exit gracefully
        	quit_program
		fi
	fi
	
    if [ -z "$INGHOME" ] || [ $INGINST -eq 0 ]; then
        return
    fi

    DBLIST=""
    if [ $NONROOTUSER -eq 0 ]; then
         DBLIST=`su - $DXUSER -c "$DXSRCBASH dxlistdb" | grep "<" | awk '{print $1}' | egrep -v '^router|^democorp$|^unspsc$|^test$' `
    else
         DBLIST=`dxlistdb | grep "<" | awk '{print $1}' | egrep -v '^router|^democorp$|^unspsc$|^test$' `
    fi
    if [ -n "$DBLIST" ]; then
        echo
        echo "The following $DXPROD databases are still installed: "
        echo "$DBLIST"
        echo
        echo "$DXPROD will not be uninstalled."
        UNINSTALLDX=0
        EXITCODE=2 # 9067: if exiting with this status, pkgadd will exit gracefully
        quit_program
    fi
}


##############################
# Remove the Reboot Scripts. #
##############################
remove_reboot()
{
    echo
    echo "-------------------------- Cleanup --------------------------"

    if [ -n "$DXHOME" -a -d $DXHOME/bin ] || [ -n "$DXWEBHOME" -a -d $DXWEBHOME/bin ]; then
        : # do nothing
    elif [ $UNINSTALLDX -eq 1 ]; then
        remove_reboot_scripts
    fi
}

###################################
# Display uninstall complete sign #
###################################
uninstall_complete()
{
    echo
    echo "#################################################################"
    echo "#                                                               #"
    echo "#                    Uninstall Complete                         #"
    echo "#                                                               #"
    echo "#################################################################"
    echo
    exit $EXITCODE
}

####################
# Advanced Screens #
####################
advanced_screens()
{
    if [ "$DX" = " " -a "$DXA" = " " -a "$DXU" = " " -a "$DXM" = " " ]; then
       echo
       echo "Please select a product then type Advanced"
       echo "to get information on that product."
       get_response cont
       return
    fi

    if [ "$DX" = "x" ]; then
        dxserver_advanced_info
        clear
    fi
    if [ "$DXA" = "x" ]; then
        dxagent_advanced_info
        clear
    fi 
    if [ "$DXM" = "x" ]; then
        dxmgmtui_advanced_info
        clear
    fi 
    if [ "$DXU" = "x" ]; then
        dxuser_advanced_info
        clear
    fi
}

############################
# Displays list of options #
############################
display_list()
{
    clear
    echo
    echo "--------------------------- Usage ---------------------------"

    echo
    echo "The following switches are available:"
    echo
    echo "   -dxserver     : Removes $DXPROD"
    echo "   -dxagent      : Removes $DXAGENTPROD"
    echo "   -dxmgmtui     : Removes $DXMGMTUIPROD"
    echo "   -all          : Removes all components"
    echo "   -silent       : Removes all components with no prompts"
    echo "   -r <dir>      : Specify a remove location of install files."
    echo "                   This allows you to use dxuninst.sh from a"
    echo "                   different location to the install files."
    exit 1
}

########################################################
# Check if installation directories are still required #
########################################################
check_empty_install_dir()
{
    echo 
    echo "Removing files and directories no longer required"

    # remove install log only if all components removed
    MSG=0
    for HOMEDIR in $DXHOME $DXWEBHOME $DXUIHOME; do
        if [ -d $HOMEDIR ]; then
            MSG=1
        fi
    done
    if [ $MSG -eq 0 ]; then
        rm -f `dirname $HOMEDIR`/*install*.log
        rm -f `dirname $HOMEDIR`/.profile
        rm -f `dirname $HOMEDIR`/.cshrc
        rm -f `dirname $HOMEDIR`/.dx*

        # remove old-style jre location
        [ -d `dirname $HOMEDIR`/jre ] && rm -f `dirname $HOMEDIR`/jre
    fi

    for HOMEDIR in $DXHOME; do
        echo "checking $HOMEDIR"
        DIR=`dirname $HOMEDIR`
        if [ -d $DIR ]; then
            if [ "$DIR" != "/" ]; then
                remove_empty_dir $DIR  > /dev/null
                if [ "`dirname $DIR`" != "/" ]; then
                    remove_empty_dir `dirname $DIR`  > /dev/null
                fi
            fi
        fi
    done

    # check old-style directory locations
    if [ -d /opt/ca/etrustdirectory ]; then
        remove_empty_dir /opt/ca/etrustdirectory  > /dev/null
    fi
    if [ -d /opt/ca ]; then
        remove_empty_dir /opt/ca  > /dev/null
    fi
    if [ -d /opt/CA/eTrustDirectory ]; then
        remove_empty_dir /opt/CA/eTrustDirectory  > /dev/null
    fi
    # Labtrack 13153: dxgrid datastores will now be placed under /opt/CA on uninstall
    #if [ -d /opt/CA ]; then
    #    remove_empty_dir /opt/CA  > /dev/null
    #fi
	#if [ -f $USERHOMEDIR/.profile ]; then
	#	rm -f $USERHOMEDIR/.profile
	#fi
	#if [ -f $USERHOMEDIR/.cshrc ]; then
	#	rm -f $USERHOMEDIR/.cshrc
	#fi
    if [ `uname` = "AIX" ]; then
        # remove the openssl library links in /usr/lib
        remove_openssl_lib
    fi
}   

uninstall_caopenssl()
{
    if [ $UNINSTALLDX -eq 0 ]; then
        return
    fi
    
	echo 
	echo "========================== CA OpenSSL UNINSTALLATION =========================="
	
	
	if [ -f /etc/profile.CA ]; then
		. /etc/profile.CA
	fi
	
	CAPKIHOME=`echo $CASHCOMP`
	if [ -z $CAPKIHOME ]; then
		CAPKIHOME=/opt/CA/SharedComponents
	fi
    
	# if CAPKIHOME does not exist it may have been copied/embedded in an Exiting User installation ("-dxuser <user>")
	# nothing to do here as the copied CAPKI will be deleted.
	if [ ! -d "$CAPKIHOME" ]; then
		return
	fi
	
	cd $CAPKIHOME
	UNINSTALL=`find . -name "uninstaller"`
	UNINSTALL=`echo $UNINSTALL`
	
	for UNINST in $UNINSTALL; do
		./$UNINST remove caller=ETRDIR verbose
		if [ $? != 0 ]; then
			echo "  CA OpenSSL uninstall failed. "
		fi
	done
}


main $1 $2 $3 $4 $5 $6 $7 $8 $9 
