#!/bin/sh
# Computer Associates DXserver Setup Script
# $Id: 
################################################################################
# dxprecheck.sh                                                                #
#                                                                              #
# Used by embedding installers to precheck dxsetup requirements.               #
# This script will exit with the exit code below based on the following        #
# conditions:                                                                  #
# 0 : all good                                                                 #
# 1 : insufficient kernel parameters                                           #
# 2 : insufficient disk space                                                  #
# 3 : validate ii_system for pre-existing ingres                               #
#                                                                              #
# 99: problem with this script                                                 #
################################################################################

DEFANS=1
SOURCEDIR=`pwd`  
RESPONSE_FILE=$SOURCEDIR/responsefile.txt 
INGUSER=ingres


. $SOURCEDIR/dxprepare.shlib
. $SOURCEDIR/dxsetup.shlib
case `uname` in
   "HP-UX" ) . $SOURCEDIR/dxsetuphpux.shlib ;;
   "SunOS" ) . $SOURCEDIR/dxsetupsolaris.shlib ;;
   "AIX"   ) . $SOURCEDIR/dxsetupaix.shlib ;;
   "Linux" ) . $SOURCEDIR/dxsetuplinux.shlib ;;
esac

######################
# process parameters #
######################
while [ $# -gt 0 ]; do
    arg=$1
    shift
    if [ $arg = "-responsefile" ]; then
        if [ $# -gt 0 ]; then
            if [ "`echo $1 | cut -c 1`" != "-" ]; then
                RESPONSE_FILE="$1"
                shift
            fi
        fi
    elif [ $arg = "-noingres" ]; then 
        NOINGRES=1
    elif [ $arg = "-use_ii_system" ]; then 
        USE_II_SYSTEM=1
        NOINGRES=1

    fi




done


##############################
# 1 : kernel parameter check #
##############################
#echo 1 : kernel parameter check 
#CHECK_KERNEL=1
#check_system_parameters 
#if [ $? != 0 ]; then
#    exit 1
#fi

###############################################
# 2 : disk space check, based on responsefile #
###############################################
echo  2 : disk space check
. $RESPONSE_FILE

check_dir_space $ETDIRHOME 32  
if [ "$RETURN" = "n" ]; then
    exit 2
fi

if [ -z "$NOINGRES" ]; then
    check_dir_space $INGDEFAULTINST 365 
    if [ "$RETURN" = "n" ]; then
        exit 2
    fi
    check_dir_space INGDATABASE 68 
    if [ "$RETURN" = "n" ]; then
        exit 2
    fi
fi

#######################
# 3 : check ii_system #
#######################
echo 3 : ii_system check
validate_use_ii_system
if [ $? != 0 ]; then
    exit 3
fi

################################
# 0 : all is well in the world #
################################
echo 0 : precheck complete
exit 0



