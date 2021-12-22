#!/bin/sh
#
# CA Technologies 
#
# Description:
#
#   Generate a private key and a certificate signing request (CSR) with information provided 
#   at the prompt and then issue the certificate using the Certificate Authority
#

CURRENT_DIR=`pwd`
BASE_DIR=$CURRENT_DIR/CA
OUT_DIR=$CURRENT_DIR/out

OPENSSL_REQ_CONFIG_FILE=$CURRENT_DIR/openssl-req.cnf
OPENSSL_CA_CONFIG_FILE=$CURRENT_DIR/openssl-ca.cnf
OPENSSL_CA_PRIVATE_KEY_FILE=$BASE_DIR/private/ca.key

# check to see if we have set up the CA before
if [ ! -f $OPENSSL_CA_PRIVATE_KEY_FILE ]; then

	echo "You have not set up your Certificate Authority yet."
	echo "Please run setup_ca.sh to set up your Certificate Authority first"
	exit
	
fi

# ask for the file base name for the key and certificate
echo "Please provide a base name for your key and certificate files"
read FILE_BASE_NAME

if [ "$FILE_BASE_NAME" = "" ]; then
	echo "No base name for your key and certificate files provided. Exiting ..."
	exit
fi

# check to see if the base name has been used already
if [ -f $OUT_DIR/$FILE_BASE_NAME.csr ]; then
	echo "File base name for your key and certificate files already used. Exiting ..."
	exit
fi
if [ -f $OUT_DIR/$FILE_BASE_NAME.key ]; then
	echo "File base name for your key and certificate files already used. Exiting ..."
	exit
fi
if [ -f $OUT_DIR/$FILE_BASE_NAME.pem ]; then
	echo "File base name for your key and certificate files already used. Exiting ..."
	exit
fi
if [ -f $OUT_DIR/$FILE_BASE_NAME.p12 ]; then
	echo "File base name for your key and certificate files already used. Exiting ..."
	exit
fi

# ask the user what kind of certificate they want to create first
echo "Are you requesting a certificate for your dxagent client (1) or for your dxagent server (2) ?"
read CERT_TYPE

# generate a certificate for dxagent client
if [ "$CERT_TYPE" = "1" ]; then
	
	# ask the user to enter the password for the pkcs12 file
	echo "Please provide a password for the PKCS12 file"
	read -s P12_PASS

	if [ "$P12_PASS" = "" ]; then
		echo "No password provided. Exiting ..."
		exit
	fi

	openssl req -config $OPENSSL_REQ_CONFIG_FILE -extensions openssl_client_extensions -newkey rsa:2048 -nodes -keyout $OUT_DIR/$FILE_BASE_NAME.key -out $OUT_DIR/$FILE_BASE_NAME.csr -outform PEM

	openssl ca -config $OPENSSL_CA_CONFIG_FILE -extensions openssl_client_extensions -batch -notext -in $OUT_DIR/$FILE_BASE_NAME.csr -out $OUT_DIR/$FILE_BASE_NAME.pem

	openssl pkcs12 -export -inkey $OUT_DIR/$FILE_BASE_NAME.key -in $OUT_DIR/$FILE_BASE_NAME.pem -out $OUT_DIR/$FILE_BASE_NAME.p12 -password pass:$P12_PASS

	echo "Your certificate and key are stored in the PKCS12 file - $OUT_DIR/$FILE_BASE_NAME.p12" 

# generate a certificate for dxagent server
elif [ "$CERT_TYPE" = "2" ]; then

	openssl req -config $OPENSSL_REQ_CONFIG_FILE -extensions openssl_server_extensions -newkey rsa:2048 -nodes -keyout $OUT_DIR/$FILE_BASE_NAME.key -out $OUT_DIR/$FILE_BASE_NAME.csr -outform PEM

	openssl ca -config $OPENSSL_CA_CONFIG_FILE -days 3650 -extensions openssl_server_extensions -batch -notext -in $OUT_DIR/$FILE_BASE_NAME.csr -out $OUT_DIR/$FILE_BASE_NAME.pem

else

	echo "Entered certificate type not supported"
	exit

fi

echo "Your certificate is stored in file - $OUT_DIR/$FILE_BASE_NAME.pem"
echo "Your private key is stored in file - $OUT_DIR/$FILE_BASE_NAME.key"

