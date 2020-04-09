#!/bin/bash
# ====CHAINCODE ARGUMENT SAMPLES ==================
# ==== Invoke marbles ====
# '{"Args":["initMarble","marble1","blue","35","tom"]}'
# '{"Args":["initMarble","marble2","red","50","tom"]}'
# '{"Args":["initMarble","marble3","blue","70","tom"]}'
# '{"Args":["transferMarble","marble2","jerry"]}'
# '{"Args":["transferMarblesBasedOnColor","blue","jerry"]}'
# '{"Args":["delete","marble1"]}'

# ==== Query marbles ====
# '{"Args":["readMarble","marble1"]}'
# '{"Args":["getMarblesByRange","marble1","marble3"]}'
# '{"Args":["getHistoryForMarble","marble1"]}'
# '{"Args":["getMarblesByRangeWithPagination","marble1","marble3","3",""]}'

# Rich Query (Only supported if CouchDB is used as state database):
# '{"Args":["queryMarblesByOwner","tom"]}'
# '{"Args":["queryMarbles","{\"selector\":{\"owner\":\"tom\"}}"]}'

# Rich Query with Pagination (Only supported if CouchDB is used as state database):
# '{"Args":["queryMarblesWithPagination","{\"selector\":{\"owner\":\"tom\"}}","3",""]}'

# Exit on first error
set -e pipefail

export PATH=${PWD}/../../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}/../../config

# import environment variables
. ./envVar.sh

setGlobals 1
parsePeerConnectionParameters 1

# try to save the marble object
peer chaincode invoke \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -C mychannel \
        -n marbles \
        -c '{"Args":["initMarble","marble5555","blue","35","tom"]}' \
        --tls \
        --cafile ${ORDERER_CA} \
		$PEER_CONN_PARMS

# wait for the chancode to commit the trasaction
echo "waiting for chaincode to reflect"
sleep 10

# try to read the marble object
peer chaincode invoke \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -C mychannel \
        -n marbles \
        -c '{"Args":["readMarble","marble5555"]}' \
        --tls \
        --cafile ${ORDERER_CA} \
		$PEER_CONN_PARMS