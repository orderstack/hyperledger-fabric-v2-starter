#!/bin/bash

# This file is run when a new channel need to be created

CHANNEL_NAME="$1"
DELAY="$2"
MAX_RETRY="$3"
VERBOSE="$4"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}

# import utils
. ./envVar.sh

CHANNEL_ARTIFACT_PATH=.$CHANNEL_ARTIFACT_PATH
if [ ! -d "$CHANNEL_ARTIFACT_PATH" ]; then
	mkdir channel-artifacts
fi

# Function to create channel transaction
createChannelTx() {

	set -x
	configtxgen -profile TwoOrgsChannel -outputCreateChannelTx $CHANNEL_ARTIFACT_PATH/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate channel configuration transaction..."
		exit 1
	fi
	echo

}

# Function to create anchor peer transaction
createAncorPeerTx() {

	for orgmsp in Org1MSP; do

		echo "#######    Generating anchor peer update for ${orgmsp}  ##########"
		set -x
		configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate $CHANNEL_ARTIFACT_PATH/${orgmsp}anchors.tx -channelID $CHANNEL_NAME -asOrg ${orgmsp}
		res=$?
		set +x
		if [ $res -ne 0 ]; then
			echo "Failed to generate anchor peer update for ${orgmsp}..."
			exit 1
		fi
		echo
	done
}

# Function to create channel
createChannel() {
	# Set the variables to the respective organization number
	setGlobals 1

	# Poll in case the raft leader is not set yet
	local rc=1
	local COUNTER=1

	# Add peers to channel
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
		sleep $DELAY
		if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
			set -x
			peer channel create -o localhost:7050 -c $CHANNEL_NAME -f $CHANNEL_ARTIFACT_PATH/${CHANNEL_NAME}.tx --outputBlock $CHANNEL_ARTIFACT_PATH/${CHANNEL_NAME}.block >&log.txt
			res=$?
			set +x
		else
			set -x
			peer channel create -o localhost:7050 -c $CHANNEL_NAME --ordererTLSHostnameOverride orderer.example.com -f $CHANNEL_ARTIFACT_PATH/${CHANNEL_NAME}.tx --outputBlock $CHANNEL_ARTIFACT_PATH/${CHANNEL_NAME}.block --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
			res=$?
			set +x
		fi
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo
	echo "===================== Channel '$CHANNEL_NAME' created ===================== "
	echo
}

# queryCommitted ORG
joinChannel() {
	ORG=$1
	setGlobals $ORG
	local rc=1
	local COUNTER=1
	## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
		sleep $DELAY
		set -x
		peer channel join -b $CHANNEL_ARTIFACT_PATH/$CHANNEL_NAME.block >&log.txt
		res=$?
		set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	echo
	verifyResult $res "After $MAX_RETRY attempts, peer0.org${ORG} has failed to join channel '$CHANNEL_NAME' "
}

# Function to update anchor peers
updateAnchorPeers() {
	ORG=$1
	setGlobals $ORG

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		set -x
		peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f $CHANNEL_ARTIFACT_PATH/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
		res=$?
		set +x
	else
		set -x
		peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f $CHANNEL_ARTIFACT_PATH/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
		res=$?
		set +x
	fi
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME' ===================== "
	sleep $DELAY
	echo
}

verifyResult() {
	if [ $1 -ne 0 ]; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
		echo
		exit 1
	fi
}

FABRIC_CFG_PATH=$PWD/configtx

## Create channeltx
echo "### Generating channel configuration transaction '${CHANNEL_NAME}.tx' ###"
createChannelTx

## Create anchorpeertx
echo "### Generating channel configuration transaction '${CHANNEL_NAME}.tx' ###"
createAncorPeerTx

FABRIC_CFG_PATH=$PWD/../../config/

## Create channel
echo "Creating channel "$CHANNEL_NAME
createChannel

## Join all the peers to the channel
echo "Join Org1 peers to the channel..."
joinChannel 1

# echo "Join Org2 peers to the channel..."
# joinChannel 2

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for org1..."
updateAnchorPeers 1

# echo "Updating anchor peers for org2..."
# updateAnchorPeers 2

echo
echo "========= Channel successfully joined =========== "
echo

exit 0
