#!/bin/bash

# Export varibles needed in the file
export PATH=$PWD/../../bin:$PWD:$PATH
export FABRIC_CFG_PATH=$PWD/configtx
export VERBOSE=false

# Set the peerOrgFolderPath path
peerOrgFolderPath=../organizations/peerOrganizations

# Versions of fabric known not to work with the test network
BLACKLISTED_VERSIONS="^1\.0\. ^1\.1\. ^1\.2\. ^1\.3\. ^1\.4\."

# Print the usage message
function printHelp() {
	echo "Usage: "
	echo "  network.sh <Mode> [Flags]"
	echo "    <Mode>"
	echo "      - 'up' - bring up fabric orderer and peer nodes. No channel is created"
	echo "      - 'up createChannel' - bring up fabric network with one channel"
	echo "      - 'createChannel' - create and join a channel after the network is created"
	echo "      - 'down' - clear the network with docker-compose down"
	echo "      - 'restart' - restart the network"
	echo
	echo "    Flags:"
	echo "    -ca <use CAs> -  create Certificate Authorities to generate the crypto material"
	echo "    -c <channel name> - channel name to use (defaults to \"mychannel\")"
	echo "    -s <dbtype> - the database backend to use: couchdb (default) or leveldb"
	echo "    -r <max retry> - CLI times out after certain number of attempts (defaults to 5)"
	echo "    -d <delay> - delay duration in seconds (defaults to 3)"
	echo "    -l <language> - the programming language of the chaincode to deploy: go (default), javascript, or java"
	echo "    -i <imagetag> - the tag to be used to launch the network (defaults to \"latest\")"
	echo "    -verbose - verbose mode"
	echo "  network.sh -h (print this message)"
	echo
	echo " Possible Mode and flags"
	echo "  network.sh up -ca -c -r -d -s -i -verbose"
	echo "  network.sh up createChannel -ca -c -r -d -s -i -verbose"
	echo "  network.sh createChannel -c -r -d -verbose"
	echo
	echo " Taking all defaults:"
	echo "	network.sh up"
	echo
	echo " Examples:"
	echo "  network.sh up createChannel -ca -c mychannel -s couchdb -i 2.0.0"
	echo "  network.sh createChannel -c channelName"
}

# Do some basic sanity checking to make sure that the appropriate versions of fabric
# binaries/images are available. In the future, additional checking for the presence
# of go or other items could be added.
function checkPrereqs() {
	## Check if your have cloned the peer binaries and configuration files.
	peer version >/dev/null 2>&1

	if [[ $? -ne 0 || ! -d "../../config" ]]; then
		echo "ERROR! Peer binary and configuration files not found.."
		echo
		echo "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
		echo "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
		exit 1
	fi
	# use the fabric tools container to see if the samples and binaries match your
	# docker images
	LOCAL_VERSION=$(peer version | sed -ne 's/ Version: //p')
	DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-tools:$IMAGETAG peer version | sed -ne 's/ Version: //p' | head -1)

	echo "LOCAL_VERSION=$LOCAL_VERSION"
	echo "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

	if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
		echo "=================== WARNING ==================="
		echo "  Local fabric binaries and docker images are  "
		echo "  out of  sync. This may cause problems.       "
		echo "==============================================="
	fi

	for UNSUPPORTED_VERSION in $BLACKLISTED_VERSIONS; do
		echo "$LOCAL_VERSION" | grep -q $UNSUPPORTED_VERSION
		if [ $? -eq 0 ]; then
			echo "ERROR! Local Fabric binary version of $LOCAL_VERSION does not match the versions supported by the test network."
			exit 1
		fi

		echo "$DOCKER_IMAGE_VERSION" | grep -q $UNSUPPORTED_VERSION
		if [ $? -eq 0 ]; then
			echo "ERROR! Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match the versions supported by the test network."
			exit 1
		fi
	done
}

# Obtain CONTAINER_IDS and remove them
# This function is called when you bring a network down
function clearContainers() {
	CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-peer.*/) {print $1}')
	if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
		echo "---- No containers available for deletion ----"
	else
		docker rm -f $CONTAINER_IDS
	fi
}

# Delete any images that were generated as a part of this setup
# specifically the following images are often left behind:
# This function is called when you bring the network down
function removeUnwantedImages() {
	DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-peer.*/) {print $3}')
	if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
		echo "---- No images available for deletion ----"
	else
		docker rmi -f $DOCKER_IMAGE_IDS
	fi
}

# Tear down running network
function networkDown() {
	# Stop org3 containers also in addition to org1 and org2, in case we were running sample to add org3
	for org in $(ls ../organizations/main); do
		CA_DOCKER_FILE=../organizations/main/${org}/docker-compose-ca.yaml
		FILE_BASE_DOCKER=../organizations/main/${org}/docker-compose-test-net.yaml
		COUCHBASE_DOCKER=../organizations/main/${org}/docker-compose-couch.yaml

		# Check if there is a .yaml file in the directory, if yes then down the image from docker
		if [ -s $CA_DOCKER_FILE ]; then
			docker-compose -f $CA_DOCKER_FILE down --volumes --remove-orphans
		fi
		if [ -s $FILE_BASE_DOCKER ]; then
			docker-compose -f $FILE_BASE_DOCKER down --volumes --remove-orphans
		fi
		if [ -s $COUCHBASE_DOCKER ]; then
			docker-compose -f ${FILE_BASE_DOCKER} -f $COUCHBASE_DOCKER down --volumes --remove-orphans
		fi
	done

	# Don't remove the generated artifacts -- note, the ledgers are always removed
	if [ "$MODE" != "restart" ]; then

		# Bring down the network, deleting the volumes
		#Delete any ledger backups
		docker run -v $PWD/..:/tmp/first-network --rm hyperledger/fabric-tools:$IMAGETAG
		rm -rf ../tmp/first-network/ledgers-backup

		#Cleanup the chaincode containers
		clearContainers
		#Cleanup images
		removeUnwantedImages
		# Remove orderer block and other channel configuration transactions and certs
		rm -rf ../system-genesis-block/*.block $peerOrgFolderPath ../organizations/ordererOrganizations

		# Remove fabric ca artifacts
		rm -rf ../code/wallet
		rm -rf *.json *.log ../code/nextblock.txt
		rm -rf ../code/addMarbles.json ../code/*.log
		rm -rf *.tar.gz

		# Loop through the ../organizations/main directory and get the name of all the 
		# organizations and remove the files generated while starting the network
		for org in $(ls ../organizations/main); do
			rm -rf ../organizations/main/${org}/fabric-ca/msp
			rm -rf ../organizations/main/${org}/fabric-ca/tls-cert.pem
			rm -rf ../organizations/main/${org}/fabric-ca/ca-cert.pem
			rm -rf ../organizations/main/${org}/fabric-ca/IssuerPublicKey
			rm -rf ../organizations/main/${org}/fabric-ca/IssuerRevocationPublicKey
			rm -rf ../organizations/main/${org}/fabric-ca/fabric-ca-server.db
		done
		# Remove channel and script artifacts
		rm -rf ../channel-artifacts log.txt ../*.tar.gz *.tx *.block

		docker stop offchaindb
		docker rm offchaindb
	fi
}

# Start the network
function networkUp() {
	# Check for any prerequisits required before starting the network
	checkPrereqs

	# Generate artifacts if they don't exist
	if [ ! -d "$peerOrgFolderPath" ]; then
		createOrgs
		createConsortium
	fi

	# Loop through the ../organizations/main directory to get the name of all the organizations
	for org in $(ls ../organizations/main); do
		FILE_BASE_DOCKER=../organizations/main/${org}/docker-compose-test-net.yaml
		COUCHBASE_DOCKER=../organizations/main/${org}/docker-compose-couch.yaml

		# If no docker-compose-test-net.yaml is found, then through an error
		if [ ! -s $FILE_BASE_DOCKER ]; then
			echo "$FILE_BASE_DOCKER not found please verify and add config"
			exit 1
		fi

		# Create a variable and store the file path of the .yaml file with "-f" added to it
		COMPOSE_FILES="-f ${FILE_BASE_DOCKER}"

		# Only if the database couchdb is selceted and if the org is not an orderer, change the 
		# COMPOSE_FILES variable to the COUCHBASE_DOCKER file path
		if [ "${DATABASE}" == "couchdb" -a "$org" != "ordererOrg" ]; then
			if [ ! -s $COUCHBASE_DOCKER ]; then
				echo "$FILE_BASE_DOCKER not found please verify and add config"
				exit 1
			fi
			COMPOSE_FILES="${COMPOSE_FILES} -f ${COUCHBASE_DOCKER}"
		fi

		set -x		
		# Get the $IMAGETAG variable from the .env file and give it to the IMAGE_TAG variable 
		# in the docker-compose-test-net.yaml file for it to use it and run the docker-compose command for the peer to start
		IMAGE_TAG=$IMAGETAG docker-compose ${COMPOSE_FILES} up -d 2>&1
		set +x
	done

	# List all the docker processes
	docker ps -a
	# If no docker process exist, throw an error
	if [ $? -ne 0 ]; then
		echo "ERROR !!!! Unable to start network"
		exit 1
	fi
}

# Create a channel by running this function
function createChannel() {

	## Bring up the network if it is not arleady up.

	if [ ! -d "$peerOrgFolderPath" ]; then
		echo "Bringing up network"
		networkUp
	fi

	# now run the script that creates a channel. This script uses configtxgen once
	# more to create the channel creation transaction and the anchor peer updates.
	# configtx.yaml is mounted in the cli container, which allows us to use it to
	# create the channel artifacts
	./createChannel.sh $CHANNEL_NAME $CLI_DELAY $MAX_RETRY $VERBOSE
	if [ $? -ne 0 ]; then
		echo "Error !!! Create channel failed"
		exit 1
	fi

}

# Create a consortium by running this function
function createConsortium() {
	# Print the path for the configtxgen file
	which configtxgen
	if [ "$?" -ne 0 ]; then
		echo "configtxgen tool not found. exiting"
		exit 1
	fi

	echo "#########  Generating Orderer Genesis block ##############"

	# Note: For some unknown reason (at least for now) the block file can't be
	# named orderer.genesis.block or the orderer will fail to launch!
	set -x
	# Run the configtxgen command the TwoOrgsOrdererGenesis, system-channel are from the configtx.yaml file
	configtxgen -profile TwoOrgsOrdererGenesis -channelID system-channel -outputBlock ../system-genesis-block/genesis.block
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate orderer genesis block..."
		exit 1
	fi
}

# Let's start creating organizations
function createOrgs() {
	# Delete any peers if exists in the organizations
	if [ -d "$peerOrgFolderPath" ]; then
		rm -Rf $peerOrgFolderPath && rm -Rf ../organizations/ordererOrganizations
	fi

	# Create crypto material using cryptogen default flag value for CRYPTO
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

		for org in $(ls ../organizations/main); do
			echo "##########################################################"
			echo "############ Create ${org} Identities ######################"
			echo "##########################################################"
			if [ -s "../organizations/main/${org}/crypto-config.yaml" ]; then
				set -x
				# Check if the crypto-config.yaml file for the organization exists and then run the command below:
				# This command creates certificates in the organizations folder for the respective orgs
				cryptogen generate --config=../organizations/main/${org}/crypto-config.yaml --output="../organizations"
				res=$?
				set +x
				if [ $res -ne 0 ]; then
					echo "Failed to generate certificates..."
					exit 1
				fi
			else
				echo "crypto-config.yaml not found for ${org}"
				exit 1
			fi
		done
	fi

	if [ "$CRYPTO" == "Certificate Authorities" ]; then
		fabric-ca-client version >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "Fabric CA client not found locally"
		fi

		echo
		echo "##########################################################"
		echo "##### Generate certificates using Fabric CA's ############"
		echo "##########################################################"

		for org in $(ls ../organizations/main); do
			echo "##########################################################"
			echo "############ Create ${org} container ######################"
			echo "##########################################################"
			if [ -s "../organizations/main/${org}/docker-compose-ca.yaml" ]; then
				set -x
				# Create certificates in the docker images by running the below comamnd
				IMAGE_TAG=$IMAGETAG docker-compose -f ../organizations/main/${org}/docker-compose-ca.yaml up -d 2>&1
				set +x
			else
				echo "docker-compose-ca.yaml not found for ${org}"
				exit 1
			fi
		done

		# Give time for docker containers to start
		sleep 10

		for org in $(ls ../organizations/main); do
			echo "##########################################################"
			echo "############ Registering enroll for ${org} ######################"
			echo "##########################################################"
			if [ -s "../organizations/main/${org}/registerEnroll.sh" ]; then
				set -x
				# Give admin access to registerEnroll.sh file
				chmod 700 ../organizations/main/${org}/registerEnroll.sh
				# Run the registerEnroll.sh file for the respective org
				. ../organizations/main/${org}/registerEnroll.sh
				set +x
			else
				echo "registerEnroll.sh not found for ${org}"
				exit 1
			fi
		done

		echo
		echo "Generate CCP files for orgs"

		. ./ccp/ccp_helper.sh
		for org in $(ls ../organizations/main); do
			if [[ $org != "ordererOrg" ]]; then
				echo "##########################################################"
				echo "############ generating ccp for ${org} ######################"
				echo "##########################################################"
				if [ -s "../organizations/main/${org}/ccp.sh" ]; then
					. ../organizations/main/${org}/ccp.sh
					# Generate ccp files by reading the respective json and yaml file configs
					echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" >$peerOrgFolderPath/${org}.example.com/connection-${org}.json
					echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" >$peerOrgFolderPath/${org}.example.com/connection-${org}.yaml
				else
					echo "ccp.sh not found for ${org}"
					exit 1
				fi
			fi
		done
	fi
}

# default variables
# Obtain the OS and Architecture string that will be used to select the correct
# native binaries for your platform, e.g., darwin-amd64 or linux-amd64
OS_ARCH=$(echo "$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
# Using crpto vs CA. default is cryptogen
CRYPTO="cryptogen"
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
MAX_RETRY=5
# default for delay between commands
CLI_DELAY=3
# channel name defaults to "mychannel"
CHANNEL_NAME="mychannel"
# use this as the default docker-compose yaml definition
COMPOSE_FILE_BASE=docker/docker-compose-test-net.yaml
# docker-compose.yaml file if you are using couchdb
COMPOSE_FILE_COUCH=docker/docker-compose-couch.yaml
# certificate authorities compose file
COMPOSE_FILE_CA=docker/docker-compose-ca.yaml

# use javascript as the default language for chaincode
CC_RUNTIME_LANGUAGE=javascript
# Chaincode version
VERSION=1
# default image tag
IMAGETAG="latest"
# default database
DATABASE="couchdb"

# cli menu here.
# Parse commandline args
if [[ $# -lt 1 ]]; then
	printHelp
	exit 0
else
	MODE=$1
	shift
fi

# parse a createChannel subcommand if used
if [[ $# -ge 1 ]]; then
	key="$1"
	if [[ "$key" == "createChannel" ]]; then
		export MODE="createChannel"
		shift
	fi
fi

# parse flags

# If the parameters given are either of the one's given below, set the variables to the respective parameters
while [[ $# -ge 1 ]]; do
	key="$1"
	case $key in
	-h)
		printHelp
		exit 0
		;;
	-c)
		CHANNEL_NAME="$2"
		shift
		;;
	-ca)
		CRYPTO="Certificate Authorities"
		;;
	-r)
		MAX_RETRY="$2"
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
	-l)
		CC_RUNTIME_LANGUAGE="$2"
		shift
		;;
	-v)
		VERSION="$2"
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

# Are we generating crypto material with this command?
if [ ! -d "$peerOrgFolderPath" ]; then
	CRYPTO_MODE="with crypto from '${CRYPTO}'"
else
	CRYPTO_MODE=""
fi

# Determine mode of operation and printing out what we asked for
if [ "$MODE" == "up" ]; then
	echo "Starting nodes with CLI timeout of '${MAX_RETRY}' tries and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE}' ${CRYPTO_MODE}"
	echo
elif [ "$MODE" == "createChannel" ]; then
	echo "Creating channel '${CHANNEL_NAME}'."
	echo
	echo "If network is not up, starting nodes with CLI timeout of '${MAX_RETRY}' tries and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE} ${CRYPTO_MODE}"
	echo
elif [ "$MODE" == "down" ]; then
	echo "Stopping network"
	echo
elif [ "$MODE" == "restart" ]; then
	echo "Restarting network"
	echo
else
	printHelp
	exit 1
fi


if [ "${MODE}" == "up" ]; then
	networkUp
elif [ "${MODE}" == "createChannel" ]; then
	createChannel
elif [ "${MODE}" == "down" ]; then
	networkDown
elif [ "${MODE}" == "restart" ]; then
	networkDown
	networkUp
else
	printHelp
	exit 1
fi

# cli ends menu here.
