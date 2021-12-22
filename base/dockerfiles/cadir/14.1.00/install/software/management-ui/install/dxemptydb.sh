#!/bin/sh

###################################################
# Script to be run a DSA user to check and empty  #
# any eTrust Directory databases 				  #
# This script adresses 13428				      #
###################################################
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
    
       
    if [ -z "$DBLIST" -o "$DBLIST" = " " ]; then
        exit 0
    fi
    
   # need to destroy all the databases 
    for DBNAME in $DBLIST; do     
  		$DXHOME/bin/dxdestroydb $DBNAME      
    done
    
exit 0
