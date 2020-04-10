# This file is run whenever a new org is created and the network is up

echo "Enroll the CA admin"
echo
ORGANIZATION_FOLDER_PATH=$PWD/../organizations/peerOrganizations
mkdir -p $ORGANIZATION_FOLDER_PATH/org1.example.com/

export FABRIC_CA_CLIENT_HOME=$ORGANIZATION_FOLDER_PATH/org1.example.com/

TLS_CERT_FILE=$PWD/../organizations/main/org1/fabric-ca/tls-cert.pem

set -x
# Generate the fabirc CA certificates
fabric-ca-client enroll -u https://admin:adminpw@localhost:7054 --caname ca-org1 --tls.certfiles $TLS_CERT_FILE
set +x

echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-org1.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-org1.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-org1.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-org1.pem
    OrganizationalUnitIdentifier: orderer' >$ORGANIZATION_FOLDER_PATH/org1.example.com/msp/config.yaml

# Register the peer0
echo
echo "Register peer0"
echo
set -x
fabric-ca-client register --caname ca-org1 --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles $TLS_CERT_FILE
set +x

# Register the User
echo
echo "Register user"
echo
set -x
fabric-ca-client register --caname ca-org1 --id.name user1 --id.secret user1pw --id.type client --tls.certfiles $TLS_CERT_FILE
set +x

# Register the org admin
echo
echo "Register the org admin"
echo
set -x
fabric-ca-client register --caname ca-org1 --id.name org1admin --id.secret org1adminpw --id.type admin --tls.certfiles $TLS_CERT_FILE
set +x

mkdir -p $ORGANIZATION_FOLDER_PATH/org1.example.com/peers
mkdir -p $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com

echo
echo "## Generate the peer0 msp"
echo
set -x
fabric-ca-client enroll -u https://peer0:peer0pw@localhost:7054 --caname ca-org1 -M $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/msp --csr.hosts peer0.org1.example.com --tls.certfiles $TLS_CERT_FILE
set +x

cp $ORGANIZATION_FOLDER_PATH/org1.example.com/msp/config.yaml $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/msp/config.yaml

echo
echo "## Generate the peer0-tls certificates"
echo
set -x
fabric-ca-client enroll -u https://peer0:peer0pw@localhost:7054 --caname ca-org1 -M $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/tls --enrollment.profile tls --csr.hosts peer0.org1.example.com --csr.hosts localhost --tls.certfiles $TLS_CERT_FILE
set +x

cp $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/tls/tlscacerts/* $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
cp $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/tls/signcerts/* $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/tls/server.crt
cp $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/tls/keystore/* $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/tls/server.key

mkdir $ORGANIZATION_FOLDER_PATH/org1.example.com/msp/tlscacerts
cp $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/tls/tlscacerts/* $ORGANIZATION_FOLDER_PATH/org1.example.com/msp/tlscacerts/ca.crt

mkdir $ORGANIZATION_FOLDER_PATH/org1.example.com/tlsca
cp $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/tls/tlscacerts/* $ORGANIZATION_FOLDER_PATH/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem

mkdir $ORGANIZATION_FOLDER_PATH/org1.example.com/ca
cp $ORGANIZATION_FOLDER_PATH/org1.example.com/peers/peer0.org1.example.com/msp/cacerts/* $ORGANIZATION_FOLDER_PATH/org1.example.com/ca/ca.org1.example.com-cert.pem

mkdir -p $ORGANIZATION_FOLDER_PATH/org1.example.com/users
mkdir -p $ORGANIZATION_FOLDER_PATH/org1.example.com/users/User1@org1.example.com

echo
echo "## Generate the user msp"
echo
set -x
fabric-ca-client enroll -u https://user1:user1pw@localhost:7054 --caname ca-org1 -M $ORGANIZATION_FOLDER_PATH/org1.example.com/users/User1@org1.example.com/msp --tls.certfiles $TLS_CERT_FILE
set +x

mkdir -p $ORGANIZATION_FOLDER_PATH/org1.example.com/users/Admin@org1.example.com

echo
echo "## Generate the org admin msp"
echo
set -x
fabric-ca-client enroll -u https://org1admin:org1adminpw@localhost:7054 --caname ca-org1 -M $ORGANIZATION_FOLDER_PATH/org1.example.com/users/Admin@org1.example.com/msp --tls.certfiles $TLS_CERT_FILE
set +x

cp $ORGANIZATION_FOLDER_PATH/org1.example.com/msp/config.yaml $ORGANIZATION_FOLDER_PATH/org1.example.com/users/Admin@org1.example.com/msp/config.yaml
