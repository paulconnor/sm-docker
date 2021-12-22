#!/bin/sh

###################################################
# Script to be run a DSA user to check and backup #
# any eTrust Directory databases                  #
###################################################

    echo
    echo "  Checking for DSA databases to checkpoint."
    echo

    # Get a list of databases to backup
    if [ ! -x $DXHOME/bin/dxlistdb ]; then
        echo "  Cannot locate dxlistdb."
        exit 1
    fi
    if [ ! -x $DXHOME/bin/dxbackupdb ]; then
        echo "  Cannot locate dxbackupdb."
        exit 1
    fi

    $DXHOME/bin/dxlistdb | grep "<"  > /dev/null
    if [ $? -eq 0 ]; then
        DBLIST=`$DXHOME/bin/dxlistdb | grep "ok" | awk '{print $1}'`
    else
        # output doesn't contain "<ok>" - v4.0 or earlier
        DBLIST=`$DXHOME/bin/dxlistdb | awk '{print $1}'`
    fi
    DBLIST=`echo $DBLIST`
    if [ -z "$DBLIST" -o "$DBLIST" = " " ]; then
        echo "  No databases to checkpoint."
        exit 0
    fi

    echo "  Checkpointing the following database(s): $DBLIST"
    echo

    $DXHOME/bin/dxbackupdb | grep keepold > /dev/null
    if [ $? -eq 0 ]; then
        KEEPOLD="-keepold"
    else
        # pre 4.0SP1
        KEEPOLD=""
    fi

    for DBNAME in $DBLIST; do
        echo "  Checkpointing $DBNAME"

        $DXHOME/bin/dxbackupdb $KEEPOLD $DBNAME
        if [ $? -ne 0 ]; then
            echo "  Checkpoint of $DBNAME failed."
        else
            echo "  Checkpoint of $DBNAME successful"
        fi
        echo
    done

    echo "  Database checkpointing complete"

exit 0
