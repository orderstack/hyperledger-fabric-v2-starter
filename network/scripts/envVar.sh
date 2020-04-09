# This is a collection of bash functions used by different scripts

ORGANIZATION_FOLDER_PATH=$PWD/../organizations
export CORE_PEER_TLS_ENABLED=true

export ORDERER_CA=${ORGANIZATION_FOLDER_PATH}/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Set OrdererOrg.Admin globals
setOrdererGlobals() {
	export CORE_PEER_LOCALMSPID="OrdererMSP"
	export CORE_PEER_TLS_ROOTCERT_FILE=${ORGANIZATION_FOLDER_PATH}/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
	export CORE_PEER_MSPCONFIGPATH=${ORGANIZATION_FOLDER_PATH}/ordererOrganizations/example.com/users/Admin@example.com/msp
}

# Set environment variables for the peer org
setGlobals() {
	local USING_ORG=""
	if [ -z "$OVERRIDE_ORG" ]; then
		USING_ORG=$1
	else
		USING_ORG="${OVERRIDE_ORG}"
	fi

	local port=""
	if [ -s ${ORGANIZATION_FOLDER_PATH}/additionalOrganizations/org${USING_ORG}/docker-compose-test-net.yaml ]; then
		port=$(grep -A1 "ports:" ${ORGANIZATION_FOLDER_PATH}/additionalOrganizations/org${USING_ORG}/docker-compose-test-net.yaml | grep "-" | awk -F":" '{print $2}')
	else
		port=$(grep -A1 "ports:" ${ORGANIZATION_FOLDER_PATH}/main/org${USING_ORG}/docker-compose-test-net.yaml | grep "-" | awk -F":" '{print $2}')
	fi
	
	echo "Using organization ${USING_ORG}"

	export CORE_PEER_LOCALMSPID="Org${USING_ORG}MSP"
	export CORE_PEER_TLS_ROOTCERT_FILE=${ORGANIZATION_FOLDER_PATH}/peerOrganizations/org${USING_ORG}.example.com/peers/peer0.org${USING_ORG}.example.com/tls/ca.crt
	export CORE_PEER_MSPCONFIGPATH=${ORGANIZATION_FOLDER_PATH}/peerOrganizations/org${USING_ORG}.example.com/users/Admin@org${USING_ORG}.example.com/msp
	export CORE_PEER_ADDRESS=localhost:$port

	if [ "$VERBOSE" == "true" ]; then
		env | grep CORE
	fi
}

# parsePeerConnectionParameters $@
# Helper function that takes the parameters from a chaincode operation
# (e.g. invoke, query, instantiate) and checks for an even number of
# peers and associated org, then sets $PEER_CONN_PARMS and $PEERS
parsePeerConnectionParameters() {
	# check for uneven number of peer and org parameters

	PEER_CONN_PARMS=""
	PEERS=""
	while [ "$#" -gt 0 ]; do
		setGlobals $1
		PEER="peer0.org$1"
		PEERS="$PEERS $PEER"
		PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"
		if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "true" ]; then
			# TLSINFO=$(eval echo "--tlsRootCertFiles \$PEER0_ORG$1_CA")
			TLSINFO=$(eval echo "--tlsRootCertFiles \$CORE_PEER_TLS_ROOTCERT_FILE")
			PEER_CONN_PARMS="$PEER_CONN_PARMS $TLSINFO"
		fi
		# shift by two to get the next pair of peer/org parameters
		shift
	done
	# remove leading space for output
	PEERS="$(echo -e "$PEERS" | sed -e 's/^[[:space:]]*//')"
}

verifyResult() {
	if [ $1 -ne 0 ]; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
		echo
		exit 1
	fi
}
