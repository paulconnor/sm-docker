#!/bin/sh

###################################################
# Script to be run a DSA user to check and dump   #
# any eTrust Directory databases to an ldif file  #
###################################################
    LDIFLOC=$1
    SOURCEDIR=$2
    LOG=$3
    echo " running dxdumpdb.sh " | $LOG > /dev/null 2>&1
    echo
    echo "============================ Dumping Database ============================" | $LOG
    echo

	# need to check for mdb databases
	cd $DXHOME/config/database
	ISMDB=0
	grep "database-name" * | awk -F= '{print $2}' | grep "mdb"
	if [ $? -eq 0 ]; then
		ISMDB=`expr $ISMDB + 1`
	fi
	grep "db-name=mdb" * 
	if [ $? -eq 0 ]; then
		ISMDB=`expr $ISMDB + 1`
	fi
		 

    # Check for dxlistdb. if dxlistdb is not found print error
    if [ ! -x $DXHOME/bin/dxlistdb ]; then
        echo "  Cannot locate dxlistdb." | $LOG
        exit 1
    fi
    if [ ! -x $DXHOME/bin/dxdumpdb ]; then
        echo "  Cannot locate dxdumpdb." | $LOG
        exit 1
    fi
    
    # get a list of databases to dump    
    $DXHOME/bin/dxlistdb | grep "<"  > /dev/null
    
    # Check to see db list contains "<ok>" if it doesnt means it version 4.0 or earlier
    if [ $? -eq 0 ]; then
        DBLIST=`$DXHOME/bin/dxlistdb | grep "ok" | awk '{print $1}'`
    else
        # output doesn't contain "<ok>" - v4.0 or earlier
        DBLIST=`$DXHOME/bin/dxlistdb | awk '{print $1}'`
    fi
    # Check to see if there are any databases to dump
    DBLIST=`echo $DBLIST`
    
    #if there is an mdb then we need to add mdb to the db list
    if [ $ISMDB != 0 ]; then
    	DBLIST=`echo $DBLIST mdb`
    fi
    
    if [ -z "$DBLIST" -o "$DBLIST" = " " ]; then
        echo "  No databases to dump."	| $LOG
        exit 0
    fi
    
    echo "  Dumping the following database(s) to LDIF: $DBLIST" | $LOG

    # dumping all the databases in the list ignoring router dsa's
    for DBNAME in $DBLIST; do
        echo
        echo "  Dumping $DBNAME to $LDIFLOC..."  | $LOG
        
        
        DSANAME=`$SOURCEDIR/dxupgradecheck -getdsa $DBNAME 2>/dev/null`
        #special case for EEM and mdb
		if [ "$DBNAME" = "mdb" ]; then
			MACHINENAME=`hostname | cut -f1 -d '.' | cut -b '1-15'`
			DSANAME="iTechPoz-$MACHINENAME"
		fi
    	
        if [ -z "$DSANAME" ] || [ "DSANAME" = " " ]; then
            DSANAME="No_DSA_$DBNAME"
            echo "  Dumping $DBNAME to LDIF" | $LOG
            $DXHOME/bin/dxdumpdb -O -f $LDIFLOC/$DSANAME.ldif.unsorted -p "" $DBNAME 
        else
            DSANAME=$DSANAME
            #13182: dxupgradecheck needs the DBNAME not the DSA name. 
            DSAPREFIX1=`$SOURCEDIR/dxupgradecheck -getdsaprefix $DBNAME 2>/dev/null`
            #DSAPREFIX=`echo $DSAPREFIX1 | /usr/bin/tr ', ' ',,' | /usr/bin/tr -s ',' `
            #13312:Using sed instead of "tr" to accomodate the situation of "o=streaming associates, c=US"
            DSAPREFIX=`echo $DSAPREFIX1 | sed -e 's/, /,/'`
        	if [ "$DBNAME" = "mdb" ]; then
            	DSAPREFIX="cn=iTechPoz"
            fi
            
            # this step is necessary because dxupgradecheck returns spaces within the string
            echo "  Dumping $DBNAME to LDIF"  | $LOG
            $DXHOME/bin/dxdumpdb -O -f $LDIFLOC/$DSANAME.ldif -p "$DSAPREFIX" -S $DSANAME $DBNAME
    
	        if [ $? -ne 0 ]; then
	            echo "  Dump of $DBNAME failed." | $LOG
	            exit 1
	        fi 
	    fi

        #echo "  Sorting the LDIF" |$LOG
        #$DXHOME/bin/ldifsort $LDIFLOC/$DSANAME.ldif.unsorted $LDIFLOC/$DSANAME.ldif > /dev/null 2>&1
        #if [ $? -ne 0 ]; then
        #    echo
        #    echo "  Sort of $DBNAME failed." | $LOG
        #    exit 1
        #fi
		if [ "$DBNAME" = "mdb" ]; then
			$DXHOME/bin/dxemptydb mdb
		fi
    done

    echo
    echo "  Dump of databases complete"     | $LOG

exit 0
