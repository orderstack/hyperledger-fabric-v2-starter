#!/bin/bash
# Exit on first error
set -e pipefail

# This file is run when a multi Org netwrok is to be set up

starttime=$(date +%s)
CC_SRC_LANGUAGE=javascript
CC_RUNTIME_LANGUAGE=node
CC_SRC_PATH=../chaincode/marbles/javascript

# launch network; create channel and join peer to channel
export PATH=${PWD}/../../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}/../../config

# import environment variables
. ./envVar.sh

echo "Packaging the marbles smart contract"
setGlobals 1
peer lifecycle chaincode package marbles.tar.gz  \
  --path $CC_SRC_PATH \
  --lang $CC_RUNTIME_LANGUAGE \
  --label marblesv1

echo "Installing smart contract on peer0.org1.example.com"
setGlobals 1
peer lifecycle chaincode install marbles.tar.gz

echo "Installing smart contract on peer0.org3.example.com"
setGlobals 3
peer lifecycle chaincode install marbles.tar.gz

echo "Query the chaincode package id"

setGlobals 1

peer lifecycle chaincode queryinstalled >&log.txt

PACKAGE_ID=$(sed -n "/marblesv1/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)

echo "Approving the chaincode definition for org1.example.com"
peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID mychannel \
    --name marbles \
    --version 1.0 \
    --init-required \
    --signature-policy AND"('Org1MSP.member','Org3MSP.member')" \
    --sequence 1 \
    --package-id $PACKAGE_ID \
    --tls \
    --cafile ${ORDERER_CA}

echo "Approving the chaincode definition for org3.example.com"

setGlobals 3
peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID mychannel \
    --name marbles \
    --version 1.0 \
    --init-required \
    --signature-policy AND"('Org1MSP.member','Org3MSP.member')" \
    --sequence 1 \
    --package-id $PACKAGE_ID \
    --tls \
    --cafile ${ORDERER_CA}

echo "Checking if the chaincode definition is ready to commit"

peer lifecycle chaincode checkcommitreadiness \
    --channelID mychannel \
    --name marbles \
    --version 1.0 \
    --sequence 1 \
    --output json \
    --init-required \
    --signature-policy AND"('Org1MSP.member','Org3MSP.member')" >&log.txt

rc=0
for var in "\"Org1MSP\": true" "\"Org3MSP\": true"
do
  grep "$var" log.txt &>/dev/null || let rc=1
done

if test $rc -eq 0; then
    echo "Chaincode definition is ready to commit"
else
  sleep 10
fi

# parsePeerConnectionParameters 1 2

# Add the organization numbers to get the respective parameteres for them
parsePeerConnectionParameters 1 3

echo "Commit the chaincode definition to the channel"
echo $PEER_CONN_PARMS

peer lifecycle chaincode commit \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID mychannel \
    --name marbles \
    --version 1.0 \
    --init-required \
    --signature-policy AND"('Org1MSP.member','Org3MSP.member')" \
    --sequence 1 \
    --tls \
    --cafile ${ORDERER_CA} \
    $PEER_CONN_PARMS
    

echo "Check if the chaincode has been committed to the channel ..."

peer lifecycle chaincode querycommitted \
  --channelID mychannel \
  --name marbles >&log.txt

EXPECTED_RESULT="Version: 1.0, Sequence: 1, Endorsement Plugin: escc, Validation Plugin: vscc"
VALUE=$(grep -o "Version: 1.0, Sequence: 1, Endorsement Plugin: escc, Validation Plugin: vscc" log.txt)
echo "$VALUE"

if [ "$VALUE" = "Version: 1.0, Sequence: 1, Endorsement Plugin: escc, Validation Plugin: vscc" ] ; then
  echo "chaincode has been committed"
else
  sleep 10
fi

echo "invoke the marbles chaincode init function ... "

peer chaincode invoke \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -C mychannel \
        -n marbles \
        --isInit \
        -c '{"Args":["Init"]}' \
        --tls \
        --cafile ${ORDERER_CA} \
        $PEER_CONN_PARMS

rm log.txt

cat <<EOF

Total setup execution time : $(($(date +%s) - starttime)) secs ...

EOF