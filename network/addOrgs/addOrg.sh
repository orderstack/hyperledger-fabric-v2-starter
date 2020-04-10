#!/bin/bash

# This script extends the Hyperledger Fabric test network by adding
# adding a third organization to the network
#

# prepending $PWD/../../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired

export PATH=${PWD}/../../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}
export VERBOSE=false
ORGANIZATION_FOLDER=../organizations
additionalOrganizationFolderPath=$ORGANIZATION_FOLDER/additionalOrganizations
peerOrgFolderPath=$ORGANIZATION_FOLDER/peerOrganizations

# Print the usage message
function printHelp() {
	echo "Usage: "
	echo "  addOrg.sh up|down|generate [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>]"
	echo "  addOrg.sh -h|--help (print this message)"
	echo "    <mode> - one of 'up', 'down', or 'generate'"
	echo "      - 'up' - add org to the sample network. You need to bring up the test network and create a channel first."
	echo "      - 'down' - bring down the test network and org nodes"
	echo "      - 'generate' - generate required certificates and org definition"
	echo "    -c <channel name> - test network channel name (defaults to \"mychannel\")"
	echo "    -ca <use CA> -  Use a CA to generate the crypto material"
	echo "    -t <timeout> - CLI timeout duration in seconds (defaults to 10)"
	echo "    -org <number> - organization number to spin up and add to the existing network (COMPULSORY FLAG)"
	echo "    -d <delay> - delay duration in seconds (defaults to 3)"
	echo "    -s <dbtype> - the database backend to use: couchdb (default) or leveldb"
	echo "    -i <imagetag> - the tag to be used to launch the network (defaults to \"latest\")"
	echo "    -verbose - verbose mode"
	echo
	echo "Typically, one would first generate the required certificates and "
	echo "genesis block, then bring up the network. e.g.:"
	echo
	echo "	addOrg.sh generate -org 3"
	echo "	addOrg.sh up -org 3"
	echo "	addOrg.sh up -c mychannel -s couchdb -org 3"
	echo "	addOrg.sh down -org 3"
	echo
	echo "Taking all defaults:"
	echo "	addOrg.sh up -org 3"
	echo "	addOrg.sh down -org 3"
}

# We use the cryptogen tool to generate the cryptographic material
# (x509 certs) for the new org.  After we run the tool, the certs will
# be put in the organizations folder with org1 and org2

# Create Organziation crypto material using cryptogen or CAs
function generateOrg() {

	# Create crypto material using cryptogen
	if [ "$CRYPTO" == "cryptogen" ]; then
		which cryptogen
		if [ "$?" -ne 0 ]; then
			echo "cryptogen tool not found. exiting"
			exit 1
		fi
		echo
		echo "##########################################################"
		echo "##### Generate certificates using cryptogen tool #########"
		echo "##########################################################"
		echo

		echo "##########################################################"
		echo "############ Create $ORG_NAME Identities ######################"
		echo "##########################################################"

		set -x
		cryptogen generate --config=$additionalOrganizationFolderPath/${ORG_NAME}/crypto-config.yaml --output="$ORGANIZATION_FOLDER"
		res=$?
		set +x

		if [ $res -ne 0 ]; then
			echo "Failed to generate certificates..."
			exit 1
		fi

	fi

	# Create crypto material using Fabric CAs
	if [ "$CRYPTO" == "Certificate Authorities" ]; then

		fabric-ca-client version >/dev/null 2>&1
		echo
		echo "##########################################################"
		echo "##### Generate certificates using Fabric CA's ############"
		echo "##########################################################"

		IMAGE_TAG=$IMAGETAG docker-compose -f $additionalOrganizationFolderPath/${ORG_NAME}/docker-compose-ca.yaml up -d 2>&1

		sleep 10

		echo "##########################################################"
		echo "############ Create $ORG_NAME Identities ######################"
		echo "##########################################################"
		chmod 700 $additionalOrganizationFolderPath/${ORG_NAME}/registerEnroll.sh
		. $additionalOrganizationFolderPath/${ORG_NAME}/registerEnroll.sh

	fi

	echo
	echo "Generate CCP files for $ORG_NAME"

	. ./ccp/ccp_helper.sh
	. $additionalOrganizationFolderPath/${ORG_NAME}/ccp.sh
	echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" >$peerOrgFolderPath/${ORG_NAME}.example.com/connection-${ORG_NAME}.json
	echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" >$peerOrgFolderPath/${ORG_NAME}.example.com/connection-${ORG_NAME}.yaml
}

# Generate org definition files
function generateOrgDefinition() {
	which configtxgen
	if [ "$?" -ne 0 ]; then
		echo "configtxgen tool not found. exiting"
		exit 1
	fi
	echo "##########################################################"
	echo "#######  Generating Org organization definition #########"
	echo "##########################################################"
	export FABRIC_CFG_PATH=$PWD/$additionalOrganizationFolderPath/${ORG_NAME}/
	set -x
	configtxgen -printOrg Org${ORGANIZATION_NUMBER}MSP >$peerOrgFolderPath/${ORG_NAME}.example.com/${ORG_NAME}.json
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate ${ORG_NAME} config material..."
		exit 1
	fi
	echo
}

# Create the new organization docker image
function OrgUp() {
	FILE_BASE_DOCKER=$additionalOrganizationFolderPath/${ORG_NAME}/docker-compose-test-net.yaml
	COUCHBASE_DOCKER=$additionalOrganizationFolderPath/${ORG_NAME}/docker-compose-couch.yaml

	if [ ! -s $FILE_BASE_DOCKER ]; then
		echo "$FILE_BASE_DOCKER not found please verify and add config"
		exit 1
	fi

	COMPOSE_FILES="-f ${FILE_BASE_DOCKER}"

	if [ "${DATABASE}" == "couchdb" ]; then
		if [ ! -s $COUCHBASE_DOCKER ]; then
			echo "$FILE_BASE_DOCKER not found please verify and add config"
			exit 1
		fi
		COMPOSE_FILES="${COMPOSE_FILES} -f ${COUCHBASE_DOCKER}"
	fi
	set -x
	IMAGE_TAG=$IMAGETAG CHANNEL_NAME=$CHANNEL_NAME docker-compose ${COMPOSE_FILES} up -d 2>&1
	set +x

	if [ $? -ne 0 ]; then
		echo "ERROR !!!! Unable to start ${ORG_NAME} network"
		exit 1
	fi
}

# Generate the needed certificates, the genesis block and start the network.
function addOrg() {

	# If the test network is not up, abort
	if [ ! -d ../organizations/ordererOrganizations ]; then
		echo
		echo "ERROR: Please, run ./network.sh up createChannel first."
		echo
		exit 1
	fi

	# generate artifacts if they don't exist
	if [ ! -d "$peerOrgFolderPath/$ORG_NAME.example.com" ]; then
		generateOrg
		generateOrgDefinition
	fi

	CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /fabric-tools/) {print $1}')
	if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
		echo "Bringing up network"
		OrgUp
	fi

	# Use the CLI container to create the configuration transaction needed to add
	# Org to the network
	echo
	echo "###############################################################"
	echo "####### Generate and submit config tx to add ${ORG_NAME} #############"
	echo "###############################################################"
	chmod 700 ./step1org.sh
	chmod 700 ./step2org.sh

	# cp ../scripts/$CHANNEL_NAME.block ./$CHANNEL_NAME.block

	docker exec --env ORG_NAME=$ORG_NAME --env ORGANIZATION_NUMBER=$ORGANIZATION_NUMBER Orgcli ./scripts/step1org.sh $CHANNEL_NAME $CLI_DELAY $CLI_TIMEOUT $VERBOSE
	if [ $? -ne 0 ]; then
		echo "ERROR !!!! Unable to create config tx"
		exit 1
	fi

	echo
	echo "###############################################################"
	echo "############### Have ${ORG_NAME} peers join network ##################"
	echo "###############################################################"
	docker exec --env ORG_NAME=$ORG_NAME --env ORGANIZATION_NUMBER=$ORGANIZATION_NUMBER Orgcli ./scripts/step2org.sh $CHANNEL_NAME $CLI_DELAY $CLI_TIMEOUT $VERBOSE
	if [ $? -ne 0 ]; then
		echo "ERROR !!!! Unable to have Org peers join network"
		exit 1
	fi

}

# Tear down running org
function networkDown() {

	# stop org3 containers also in addition to org1 and org2, in case we were running sample to add org3
	CA_DOCKER_FILE=../organizations/additionalOrganizations/$ORG_NAME/docker-compose-ca.yaml
	FILE_BASE_DOCKER=../organizations/additionalOrganizations/$ORG_NAME/docker-compose-test-net.yaml
	COUCHBASE_DOCKER=../organizations/additionalOrganizations/$ORG_NAME/docker-compose-couch.yaml

	if [ -s $CA_DOCKER_FILE ]; then
		IMAGE_TAG=$IMAGETAG CHANNEL_NAME=$CHANNEL_NAME docker-compose -f $CA_DOCKER_FILE down --volumes
	fi
	if [ -s $FILE_BASE_DOCKER ]; then
		IMAGE_TAG=$IMAGETAG CHANNEL_NAME=$CHANNEL_NAME  docker-compose -f $FILE_BASE_DOCKER down --volumes
	fi
	if [ -s $COUCHBASE_DOCKER ]; then
		IMAGE_TAG=$IMAGETAG CHANNEL_NAME=$CHANNEL_NAME  docker-compose -f ${FILE_BASE_DOCKER} -f $COUCHBASE_DOCKER down --volumes
	fi

	# Don't remove the generated artifacts -- note, the ledgers are always removed
	# Bring down the network, deleting the volumes
	# remove orderer block and other channel configuration transactions and certs
	rm -rf $peerOrgFolderPath/${ORG_NAME}.example.com

	# remove fabric ca artifacts

	rm -rf ../organizations/additionalOrganizations/${ORG_NAME}/fabric-ca/msp
	rm -rf ../organizations/additionalOrganizations/${ORG_NAME}/fabric-ca/tls-cert.pem
	rm -rf ../organizations/additionalOrganizations/${ORG_NAME}/fabric-ca/ca-cert.pem
	rm -rf ../organizations/additionalOrganizations/${ORG_NAME}/fabric-ca/IssuerPublicKey
	rm -rf ../organizations/additionalOrganizations/${ORG_NAME}/fabric-ca/IssuerRevocationPublicKey
	rm -rf ../organizations/additionalOrganizations/${ORG_NAME}/fabric-ca/fabric-ca-server.db

	# remove channel and script artifacts
	# rm -rf ../channel-artifacts log.txt ../*.tar.gz *.tx *.block
}

# Obtain the OS and Architecture string that will be used to select the correct
# native binaries for your platform
OS_ARCH=$(echo "$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up

# Using crpto vs CA. default is cryptogen
CRYPTO="cryptogen"

export ORGANIZATION_NUMBER=0

CLI_TIMEOUT=10
#default for delay
CLI_DELAY=3
# channel name defaults to "mychannel"
CHANNEL_NAME="mychannel"
# default image tag
IMAGETAG="latest"
# database
DATABASE="couchdb"

# Parse commandline s

## Parse mode
if [[ $# -lt 1 ]]; then
	printHelp
	exit 0
else
	MODE=$1
	shift
fi

# parse flags

while [[ $# -ge 1 ]]; do
	key="$1"
	case $key in
	-h)
		printHelp
		exit 0
		;;
	-org)
		export ORGANIZATION_NUMBER="$2"
		shift
		;;
	-c)
		CHANNEL_NAME="$2"
		shift
		;;
	-ca)
		CRYPTO="Certificate Authorities"
		;;
	-t)
		CLI_TIMEOUT="$2"
		shift
		;;
	-d)
		CLI_DELAY="$2"
		shift
		;;
	-s)
		DATABASE="$2"
		shift
		;;
	-i)
		IMAGETAG=$(go env GOARCH)"-""$2"
		shift
		;;
	-verbose)
		VERBOSE=true
		shift
		;;
	*)
		echo
		echo "Unknown flag: $key"
		echo
		printHelp
		exit 1
		;;
	esac
	shift
done

export ORG_NAME="org${ORGANIZATION_NUMBER}"

if [[ "$ORGANIZATION_NUMBER" -eq 0 ]]; then
	echo "please provide valid organization number"
	exit 1
elif [[ ! -d "$additionalOrganizationFolderPath/$ORG_NAME" ]]; then
	echo "Please add all organization $ORG_NAME to $additionalOrganizationFolderPath/$ORG_NAME folder"
	exit 1
fi

# Determine whether starting, stopping, restarting or generating for announce
if [ "$MODE" == "up" ]; then
	echo "Add $ORG_NAME to channel '${CHANNEL_NAME}' with '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE}'"
	echo
elif [ "$MODE" == "down" ]; then
	EXPMODE="Stopping org"
elif [ "$MODE" == "generate" ]; then
	EXPMODE="Generating certs and organization definition for $ORG_NAME"
else
	printHelp
	exit 1
fi

#Create the network using docker compose
if [ "${MODE}" == "up" ]; then
	addOrg
elif [ "${MODE}" == "down" ]; then ## Clear the network
	networkDown
elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
	generateOrg
	generateOrgDefinition
else
	printHelp
	exit 1
fi
