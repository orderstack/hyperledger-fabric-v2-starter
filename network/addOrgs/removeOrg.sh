#!/bin/bash

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

echo $CHANNEL_NAME

# import environment variables
. ./scripts/envVarCLI.sh

fetchChannelConfig() {
	ORG=$1
	CHANNEL=$2
	OUTPUT=$3

	setOrdererGlobals

	setGlobals $ORG

	echo "Fetching the most recent configuration block for the channel"
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		set -x
		peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL --cafile $ORDERER_CA
		set +x
	else
		set -x
		peer channel fetch config config_block.pb -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL --tls --cafile $ORDERER_CA
		set +x
	fi

	echo "Decoding config block to JSON and isolating config to ${OUTPUT}"
	set -x
	configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config >"${OUTPUT}"
	set +x
}

createConfigUpdate() {
	CHANNEL=$1
	ORIGINAL=$2
	MODIFIED=$3
	OUTPUT=$4

	set -x
	configtxlator proto_encode --input "${ORIGINAL}" --type common.Config >original_config.pb
	configtxlator proto_encode --input "${MODIFIED}" --type common.Config >modified_config.pb
	configtxlator compute_update --channel_id "${CHANNEL}" --original original_config.pb --updated modified_config.pb >config_update.pb
	configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate >config_update.json
	echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . >config_update_in_envelope.json
	configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope >"${OUTPUT}"
	set +x
}

# signConfigtxAsPeerOrg <org> <configtx.pb>
# Set the peerOrg admin of an org and signing the config update
signConfigtxAsPeerOrg() {
	PEERORG=$1
	TX=$2
	setGlobals $PEERORG
	set -x
	peer channel signconfigtx -f "${TX}"
	set +x
}

echo
echo "========= Creating config transaction to remove org from network =========== "
echo

# Fetch the config for the channel, writing it to config.json
fetchChannelConfig 1 ${CHANNEL_NAME} config.json

# Modify the configuration to append the new org
set -x
jq "del(.channel_group.groups.Application.groups.${ORG_NAME^}MSP)" config.json > modified_config.json
set +x

echo
echo "========= Modified config transaction to remove org from network =========== "
echo


createConfigUpdate ${CHANNEL_NAME} config.json modified_config.json org_update_in_envelope.pb

echo
echo "========= Config transaction to remove org to network created ===== "
echo

echo "Signing config transaction"
echo
signConfigtxAsPeerOrg 1 org_update_in_envelope.pb

for file in ./organizations/main/*; do
	orgName=${file##*/}
	echo "$orgName"
	if [[ "$orgName" != "ordererOrg" ]]; then
		echo
		echo "========= Submitting transaction from a different peer (peer0.$orgName) which also signs it ========= "
		echo
		ORG_NUM=$(echo "$orgName" | grep -o '[0-9]\+')

		setGlobals $ORG_NUM
		set -x
		peer channel update -f org_update_in_envelope.pb -c ${CHANNEL_NAME} -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${ORDERER_CA}
		set +x
	fi
done

echo
echo "========= Config transaction to remove org to network submitted! =========== "
echo

exit 0