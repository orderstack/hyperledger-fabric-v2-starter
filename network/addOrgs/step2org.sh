#!/bin/bash
#



# This script is designed to be run in the orgcli container as the
# second step of the EYFN tutorial. It joins the org peers to the
# channel previously setup in the BYFN tutorial and install the
# chaincode as version 2.0 on peer0.org.
#

echo
echo "========= Getting Org on to your test network ========= "
echo
CHANNEL_NAME="$1"
DELAY="$2"
TIMEOUT="$3"
VERBOSE="$4"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${TIMEOUT:="10"}
: ${VERBOSE:="false"}
COUNTER=1
MAX_RETRY=5

# import environment variables
. ./scripts/envVarCLI.sh

## Sometimes Join takes time hence RETRY at least 5 times
joinChannelWithRetry() {
	ORG=$1
	setGlobals $ORG

	set -x
	peer channel join -b $CHANNEL_NAME.block >&log.txt
	res=$?
	set +x
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=$(expr $COUNTER + 1)
		echo "peer0.org${ORG} failed to join the channel, Retry after $DELAY seconds"
		sleep $DELAY
		joinChannelWithRetry $PEER $ORG
	else
		COUNTER=1
	fi
	verifyResult $res "After $MAX_RETRY attempts, peer0.org${ORG} has failed to join channel '$CHANNEL_NAME' "
}

echo "Fetching channel config block from orderer..."
set -x
peer channel fetch 0 $CHANNEL_NAME.block -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME --tls --cafile $ORDERER_CA >&log.txt
res=$?
set +x
cat log.txt
verifyResult $res "Fetching config block from orderer has Failed"

joinChannelWithRetry ${ORGANIZATION_NUMBER}
echo "===================== peer0.${ORG_NAME} joined channel '$CHANNEL_NAME' ===================== "

echo
echo "========= Finished adding ${ORG_NAME^} to your test network! ========= "
echo

exit 0
