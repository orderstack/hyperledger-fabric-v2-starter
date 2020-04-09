echo
echo "Enroll the CA admin"
echo

ORGANIZATION_FOLDER_PATH=../organizations/peerOrganizations
TLS_CERT_FILE=$PWD/../organizations/additionalOrganizations/org3/fabric-ca/tls-cert.pem

mkdir -p $ORGANIZATION_FOLDER_PATH/org3.example.com/

export FABRIC_CA_CLIENT_HOME=${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/
#  rm -rf $FABRIC_CA_CLIENT_HOME/fabric-ca-client-config.yaml
#  rm -rf $FABRIC_CA_CLIENT_HOME/msp

set -x
fabric-ca-client enroll -u https://admin:adminpw@localhost:11054 --caname ca-org3 --tls.certfiles $TLS_CERT_FILE
set +x

echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-11054-ca-org3.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-11054-ca-org3.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-11054-ca-org3.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-11054-ca-org3.pem
    OrganizationalUnitIdentifier: orderer' >${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/msp/config.yaml

echo
echo "Register peer0"
echo
set -x
fabric-ca-client register --caname ca-org3 --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles $TLS_CERT_FILE
set +x

echo
echo "Register user"
echo
set -x
fabric-ca-client register --caname ca-org3 --id.name user1 --id.secret user1pw --id.type client --tls.certfiles $TLS_CERT_FILE
set +x

echo
echo "Register the org admin"
echo
set -x
fabric-ca-client register --caname ca-org3 --id.name org3admin --id.secret org3adminpw --id.type admin --tls.certfiles $TLS_CERT_FILE
set +x

mkdir -p $ORGANIZATION_FOLDER_PATH/org3.example.com/peers
mkdir -p $ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com

echo
echo "## Generate the peer0 msp"
echo
set -x
fabric-ca-client enroll -u https://peer0:peer0pw@localhost:11054 --caname ca-org3 -M ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/msp --csr.hosts peer0.org3.example.com --tls.certfiles $TLS_CERT_FILE
set +x

cp ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/msp/config.yaml ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/msp/config.yaml

echo
echo "## Generate the peer0-tls certificates"
echo
set -x
fabric-ca-client enroll -u https://peer0:peer0pw@localhost:11054 --caname ca-org3 -M ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/tls --enrollment.profile tls --csr.hosts peer0.org3.example.com --csr.hosts localhost --tls.certfiles $TLS_CERT_FILE
set +x

cp ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/tls/tlscacerts/* ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
cp ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/tls/signcerts/* ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/tls/server.crt
cp ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/tls/keystore/* ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/tls/server.key

mkdir ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/msp/tlscacerts
cp ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/tls/tlscacerts/* ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/msp/tlscacerts/ca.crt

mkdir ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/tlsca
cp ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/tls/tlscacerts/* ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/tlsca/tlsca.org3.example.com-cert.pem

mkdir ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/ca
cp ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/peers/peer0.org3.example.com/msp/cacerts/* ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/ca/ca.org3.example.com-cert.pem

mkdir -p $ORGANIZATION_FOLDER_PATH/org3.example.com/users
mkdir -p $ORGANIZATION_FOLDER_PATH/org3.example.com/users/User1@org3.example.com

echo
echo "## Generate the user msp"
echo
set -x
fabric-ca-client enroll -u https://user1:user1pw@localhost:11054 --caname ca-org3 -M ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/users/User1@org3.example.com/msp --tls.certfiles $TLS_CERT_FILE
set +x

mkdir -p $ORGANIZATION_FOLDER_PATH/org3.example.com/users/Admin@org3.example.com

echo
echo "## Generate the org admin msp"
echo
set -x
fabric-ca-client enroll -u https://org3admin:org3adminpw@localhost:11054 --caname ca-org3 -M ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/users/Admin@org3.example.com/msp --tls.certfiles $TLS_CERT_FILE
set +x

cp ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/msp/config.yaml ${PWD}/$ORGANIZATION_FOLDER_PATH/org3.example.com/users/Admin@org3.example.com/msp/config.yaml
