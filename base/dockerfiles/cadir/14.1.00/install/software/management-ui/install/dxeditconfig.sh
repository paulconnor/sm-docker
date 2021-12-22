#!/bin/sh

###################################################
# Script to be run a DSA user to check and        #
# users config files to contain the new dxgrid    #
# This script accepts three parameters the backup #
# location, location for the new grid files and   #
# the grid size                                      #
###################################################

    echo " running dxeditconfig.sh " | $LOG > /dev/null 2>&1
    #get a list of the dsa's which need their config edited. 
    LDIFLOC=$1
    DEFAULTDXGRIDLOC=$2
    DXGRIDSIZE=$3
    LOG=$4

    # get a list of all the LDIFs that need to be reloaded into dxgrid. 
    if [ ! -d $LDIFLOC ]; then
        echo "  Cannot locate Backup location where LDIF files are stored." | $LOG
        exit 1
    fi
   
    cd $LDIFLOC
    #13323: need to check if there are any files to list
    ls *.ldif > /dev/null 2>&1
    if [ $? = 0 ]; then
	    DSALIST=`ls *.ldif | awk -F. '{print $1}' `
	    DSALIST=`echo $DSALIST`
    else
    	DSALIST=" "
    fi
    
    if [ -z "$DSALIST" -o "$DSALIST" = " " ]; then
        echo "No DSAs found. No config files to edit" | $LOG
        exit 1
    fi

    if [ -z "$DEFAULTDXGRIDLOC" ] || [ "$DEFAULTDXGRIDLOC" = " " ]; then
        DEFAULTDXGRIDLOC=$DXHOME/data
    fi

    echo
    echo "  Checking the following list: $DSALIST" |$LOG
    
    # loop through the list of DSAs and configure the config file to remove cache 
    # settings and the db location and replace with dxgrid stuff

    for DSANAME in $DSALIST; do
        
    	if [ "$DSANAME" = "iTechPoz-"`hostname` ]; then
			cd $DXHOME/config/knowledge
			cp $DXHOME/config/knowledge/$DSANAME.dxc $DXHOME/config/knowledge/$DSANAME.dxc.tmp
			sed -e 's/ssl-encryption/ssl-encryption-remote/' \
			$DXHOME/config/knowledge/$DSANAME.dxc.tmp > $DXHOME/config/knowledge/$DSANAME.dxc
			
			cp $DXHOME/config/knowledge/$DSANAME-Router.dxc $DXHOME/config/knowledge/$DSANAME-Router.dxc.tmp
			sed -e 's/ssl-encryption/ssl-encryption-remote/' \
			$DXHOME/config/knowledge/$DSANAME-Router.dxc.tmp > $DXHOME/config/knowledge/$DSANAME-Router.dxc
			
			rm -rf $DXHOME/config/knowledge/$DSANAME.dxc.tmp $DXHOME/config/knowledge/$DSANAME-Router.dxc.tmp
		fi
		
        cd $DXHOME/config/servers
        if [ ! -f $DSANAME.dxi ]; then
            echo "  $DSANAME had no DSAs using it. No Datastore will be created." | $LOG
            continue # do the next one
        fi
        ISROUTER="n"
        grep 'source \"../database' $DSANAME.dxi > /dev/null
        if [ $? = 0 ]; then
            grep '.#' $DSANAME.dxi | grep 'source \"../database' > /dev/null
            if [ $? = 0 ]; then
                ISROUTER="y"
            fi
            grep "^#" $DSANAME.dxi | grep "source \"../database" > /dev/null
            if [ $? = 0 ]; then
                ISROUTER="y"
            fi
        else
            ISROUTER="y" 
        fi
        if [ "$ISROUTER" = "y" ]; then
            echo "    $DSANAME is a router DSA. Config will not be edited." | $LOG
            continue # do the next one
        fi

        grep 'set dxgrid-db-location' $DSANAME.dxi > /dev/null
        if [ $? = 0 ]; then
            echo "    You already have a Datastore configured for $DSANAME. Config will not be edited." | $LOG
            continue # do the next one
        fi
	        
        DXGRIDLOC=$DEFAULTDXGRIDLOC/$DSANAME
            
        if [ ! -d $DXGRIDLOC ]; then
            mkdir -p $DXGRIDLOC
        fi
        
        echo 											   | $LOG    
        echo "  Editing the config file for DSA $DSANAME " | $LOG
        cp  $DXHOME/config/servers/$DSANAME.dxi  $DXHOME/config/servers/$DSANAME.dxi.tmp
        sed -e '/database\//s/source/#(removed by dxsetup)source/' \
            -e 's/set max-cache-size/#(removed by dxsetup)set max-cache-size/' \
            -e 's/set cache-load-all/#(removed by dxsetup)set cache-load-all/' \
            -e 's/set cache-attrs/#(removed by dxsetup)set cache-attrs/' \
            -e 's/set cache-index/#(removed by dxsetup)set cache-index/' \
            -e 's/set lookup-cache/#(removed by dxsetup)set lookup-cache/' \
            -e 's/set cache-load-all/#(removed by dxsetup)set cache-load-all/' \
        $DXHOME/config/servers/$DSANAME.dxi.tmp > $DXHOME/config/servers/$DSANAME.dxi
        
        #13053: install now checks for the size of the grid file and uses that. 
        if [ $DXGRIDSIZE -eq 0 ]; then
	        DXGRIDSIZE1=`dxloaddb -n -s $DSANAME $LDIFLOC/$DSANAME.ldif |grep "Total Datasize" |awk -F: '{print $2}'` 
	        DXGRIDSIZE1=`echo $DXGRIDSIZE1`
	        DXGRIDSIZE=`expr $DXGRIDSIZE1 \* 2`
	        
	        #13663: if the proposed gridsize is less then 500 MB we will make it 500MB      
	        
	        if [ -z "$DXGRIDSIZE" ] || [ "$DXGRIDSIZE" = " " ] || [ $DXGRIDSIZE -le 500 ]; then       
	        	DXGRIDSIZE=500
	        fi
        fi
        
        echo "# DXgrid configuration (added by dxsetup)" >> $DXHOME/config/servers/$DSANAME.dxi
        echo "set dxgrid-db-location = \"$DXGRIDLOC\";" >> $DXHOME/config/servers/$DSANAME.dxi
        echo "set dxgrid-db-size = $DXGRIDSIZE;" >> $DXHOME/config/servers/$DSANAME.dxi
        #echo "set max-cache-size = 1000;" >> $DXHOME/config/servers/$DSANAME.dxi
        echo "set cache-index = all-attributes;" >> $DXHOME/config/servers/$DSANAME.dxi

        if [ "$ISROUTER" = "n" ]; then
            echo "set lookup-cache = true;" >> $DXHOME/config/servers/$DSANAME.dxi
        fi
        
        echo "   Finished editing the config file for DSA $DSANAME " | $LOG
        
        #13491 - need to reset gridsize just incase it gets set to none" 
        DXGRIDSIZE=$3
    done    
    echo
exit 0
