#!/bin/sh

########################################################
# Script to be run a DSA user to check and upgrade     #
# any eTrust Directory databases                       #
########################################################

    echo
    echo "  Checking if any DSA databases require upgrading."
    echo

    # Get a list of databases to upgrade
    if [ ! -x $DXHOME/bin/dxlistdb ]; then
        echo "  Fatal error. Cannot locate dxlistdb."
        exit 1
    fi
    if [ ! -x $DXHOME/bin/dxupgradedb ]; then
        echo "  Fatal error. Cannot locate dxupgradedb."
        exit 1
    fi

    DBLIST=`$DXHOME/bin/dxlistdb | grep "needs upgrading" | awk '{print $1}'`
    DBLIST=`echo "$DBLIST" | /usr/bin/tr '\n' ' '`
    if [ -z "$DBLIST" -o "$DBLIST" = " " ]; then
        echo "  No databases require upgrading."
        exit 0
    fi

    echo "  Upgrading the following database(s): $DBLIST"
    echo "  from `pwd`" # this is where the .out and .upl files are written
    echo
#    echo "  This may take a long time depending on the size of the databases."
#    echo

    for DBNAME in $DBLIST; do
        echo "  Upgrading $DBNAME"

        $DXHOME/bin/dxupgradedb $DBNAME
        if [ $? -ne 0 ]; then
            echo "  Upgrade of $DBNAME failed."
            echo "  You will need to resolve this issue and run dxupgradedb"
            echo "  against the database after the upgrade is complete."
            DBERROR="- with errors."
        else
            echo "  Upgrade of $DBNAME successful"
        fi
        echo
    done

    echo "  Database upgrading complete $DBERROR"

    if [ -n "$DBERROR" ]; then
        exit 22
    fi


exit 0
