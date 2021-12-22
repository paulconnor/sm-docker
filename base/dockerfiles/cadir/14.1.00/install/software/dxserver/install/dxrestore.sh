#!/bin/sh
##################################################
# This script needs to be run as DSA and creates #
# the relevant dxgrid datastores and reloads the #
# data that was previously in Ingres             #
##################################################

LDIFLOC=$1
NOLOAD=$2
LOADDATA=$3
LOG=$4
main()
{
echo " running dxrestore.sh" | $LOG > /dev/null 2>&1

RESTOREERROR=0
# get a list of dxgrid datastores to create    
cd $LDIFLOC

	#13323: need to check if there are files to list
	ls *.ldif > /dev/null 2>&1
	if [ $? = 0 ]; then
		DXGRIDLIST=`ls *.ldif | awk -F. '{print $1}'`
	else
		DXGRIDLIST=" " 
	fi
	        
    DXGRIDLIST=`echo $DXGRIDLIST`
    if [ -z "$DXGRIDLIST" -o "$DXGRIDLIST" = " " ]; then
        echo "  No datastores to create." | $LOG
    fi
    
    # check to see if we have dxnewdb. If not then we cant continue
    if [ ! -x $DXHOME/bin/dxnewdb ]; then
        echo "  Cannot locate dxnewdb." | $LOG
        RESTOREERROR=`expr $RESTOREERROR + 1`
        return
    fi
    #13763 - need to split the upgrade into 2 parts. 
    if [ "$NOLOAD" = "yes" ]; then  
		PARAMLOG=cadir_noload_list.txt
		PARAMLIST=$DXHOME/$PARAMLOG
		touch $PARAMLIST
		chmod 666 $PARAMLIST
		echo "LDIFLOC=$LDIFLOC" >> $PARAMLIST
		echo "DXGRIDLIST=\"$DXGRIDLIST\"" >> $PARAMLIST
	fi
	
	
    # Creating the new dxgrid datastores
    for DSANAME in $DXGRIDLIST; do
        DXGRIDLOC=`cat $DXHOME/config/servers/$DSANAME.dxi | grep "dxgrid-db-location" | awk -F= '{print $2}' | /usr/bin/tr '"' ' '| /usr/bin/tr ';' ' '`
        DXGRIDLOC=`echo $DXGRIDLOC`
    	DXGRIDSIZE=`cat $DXHOME/config/servers/$DSANAME.dxi | grep "dxgrid-db-size" | awk -F= '{print $2}' | /usr/bin/tr '"' ' '| /usr/bin/tr ';' ' '`
    	DXGRIDSIZE=`echo $DXGRIDSIZE`
        echo $DSANAME | grep No_DSA > /dev/null
        if [ $? = 0 ]; then
            echo "  No Datastore created for $DSANAME" | $LOG
            continue # do the next one
        fi
        
        if [ "$DXGRIDSIZE" = "none" ]; then
        	DXGRIDSIZE=0
        fi
        
        check_dir_space $DXGRIDLOC $DXGRIDSIZE 
        if [ $RETURN = "n" ]; then
        	echo
        	echo "   You will need to free up some disk space and recreate your datastore for $DSANAME"  | $LOG
        	echo "   Creating Datastore for $DSANAME failed."  | $LOG
        	RESTOREERROR=`expr $RESTOREERROR + 1`
        	continue
        else
           # if [ "$LOADDATA" != "yes" ]; then
		   #    echo
	       # 	echo "  Creating datastore for $DSANAME... " | $LOG
		   #     $DXHOME/bin/dxnewdb $DSANAME	      		
		   #     if [ $? -ne 0 ]; then
		   #        	echo "  Creating datastore for $DSANAME failed." | $LOG
		   #        	continue # do the next one
		   #     fi
		   # fi
	        
	        # dxloaddb seems to be happy enough without a prefix. Just as well, 
	        # because dxupgradecheck -getdsaprefix doesn't appear to work against r12.1
			if [ "$NOLOAD" != "yes" ]; then	
		        if [ -f $DXGRIDLOC/$DSANAME.db ]; then
		        	echo 
		        	echo "  There appears to be a datastore file for $DSANAME already. " | $LOG
		        	echo "  Setup will not create and reload the data for $DSANAME. " | $LOG
		        	echo 
		        	continue
		        	RESTOREERROR=`expr $RESTOREERROR + 1`
		        else
			        $DXHOME/bin/dxloaddb $DSANAME $LDIFLOC/$DSANAME.ldif
			        if [ $? -ne 0 ]; then
			            echo "  Load of $DSANAME failed." | $LOG
			            RESTOREERROR=`expr $RESTOREERROR + 1`
			        else
			            echo "  Load of $DSANAME successful" | $LOG
			        fi
           		fi
        	else
        		echo " No data has been loaded for $DSANAME" | $LOG 
	        fi
        fi
        rm $DXHOME/config/servers/$DSANAME.dxi.tmp > /dev/null 2>&1
        #rm $LDIFLOC/$DSANAME.ldif.unsorted
    done

    echo
    echo "  Restoration of DSAs complete." | $LOG
#13929 - if any DSAs fail to restore we need to return with non 0
if [ $RESTOREERROR -ne 0 ]; then
	exit 1
else     
	exit 0
fi
}
########################################################
# check available space, given a directory path.       #
# this works even if the directory path doesn't exist. #
########################################################
check_dir_space()
{
    CHECKDIR=$1
    CHECKSPACE=$2

    while [ "${CHECKDIR}" ]; do
    # does directory exist ?
        if [ -d $CHECKDIR ]; then
            # check that filesystem of directory has enough space
            fs_space $CHECKDIR
            if [ $RETURN -lt $CHECKSPACE ]; then
                echo "    \`${CHECKDIR}' only has $RETURN Mb of free space." | $LOG
                RETURN="n"
                return
            else
                RETURN="y"
                return
            fi
        else
            # chop last arc of the path
            CHECKDIR=`dirname $CHECKDIR`
        fi
    done

    RETURN="n"
    return
}

fs_space()
{    
    OS=`uname`
    case $OS in 
		"SunOS" )
			RETURN=`/usr/bin/df -k $1 | awk '$4 ~ /^([0-9])+/ { print int($4/1024) }'`
			;;
		"HP-UX" )
			RETURN=`/usr/bin/df -k $1 | awk '$2 == "free" { print int($1/1000) }'`
			;;
		"AIX" ) 
			 RETURN=`/usr/bin/df -k $1 | awk '$3 != "Free" { print int($3/1024) }'`
			 ;;
		"Linux" )
			 RETURN=`/bin/df -Pk $1 | awk '$1 != "Filesystem" { print int($4/1024) }'`
			;;
	esac
}   
main
