#!/bin/sh
#
# CA Technologies 
#
# Description:
#
#   Creates a Certificate Authority (CA) using openssl commands
#

CURRENT_DIR=`pwd`
BASE_DIR=$CURRENT_DIR/CA
OUT_DIR=$CURRENT_DIR/out

SERIAL_FILE=$BASE_DIR/serial
INDEX_FILE=$BASE_DIR/index.txt
CERTS_DIRECTORY=$BASE_DIR/certs
PRIVATE_KEY_DIRECTORY=$BASE_DIR/private
CRL_DIRECTORY=$BASE_DIR/crl

echo "Certificate Authority will be running in directory " $BASE_DIR

# check to see if we have set up the CA before
if [ -f $PRIVATE_KEY_DIRECTORY/ca.key ]; then

	echo "You have set up your Certificate Authority before."
	echo "Do you want to delete existing Certificate Authority and start a new one (y/n) ?"
	read START_NEW_CA

	if [ ! "$START_NEW_CA" = "y" ]; then
		exit
	else
                echo "Deleting files and directories of the existing Certificate Authority ... "
		rm -f -r $BASE_DIR
		echo "Done !"
	fi
fi

echo "Creating directories and files for the Certificate Authority ... "
mkdir -p $BASE_DIR
mkdir -p $OUT_DIR
mkdir -p $CERTS_DIRECTORY
mkdir -p $PRIVATE_KEY_DIRECTORY
mkdir -p $CRL_DIRECTORY
echo "01" > $SERIAL_FILE
touch $INDEX_FILE
echo "Done !"

echo "Please enter information about your Certificate Authority when prompted"
echo ""

# this will generate a self-signed CA certificate with the information provided at the prompt
openssl req -config $CURRENT_DIR/openssl-ca.cnf -x509 -nodes -days 3650 -newkey rsa:2048 -out $CERTS_DIRECTORY/ca.pem -outform PEM -keyout $PRIVATE_KEY_DIRECTORY/ca.key





