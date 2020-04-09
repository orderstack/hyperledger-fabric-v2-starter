echo
echo "Enroll the CA admin"
ORGANIZATION_FOLDER_PATH=$PWD/../organizations/ordererOrganizations
mkdir -p $ORGANIZATION_FOLDER_PATH/example.com

export FABRIC_CA_CLIENT_HOME=$ORGANIZATION_FOLDER_PATH/example.com

TLS_CERT_FILE=$PWD/../organizations/main/ordererOrg/fabric-ca/tls-cert.pem

set -x
fabric-ca-client enroll -u https://admin:adminpw@localhost:9054 --caname ca-orderer --tls.certfiles $TLS_CERT_FILE
set +x

echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: orderer' >$ORGANIZATION_FOLDER_PATH/example.com/msp/config.yaml

echo
echo "Register orderer"
echo
set -x
fabric-ca-client register --caname ca-orderer --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles $TLS_CERT_FILE
set +x

echo
echo "Register the orderer admin"
echo
set -x
fabric-ca-client register --caname ca-orderer --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin --tls.certfiles $TLS_CERT_FILE
set +x

mkdir -p $ORGANIZATION_FOLDER_PATH/example.com/orderers
mkdir -p $ORGANIZATION_FOLDER_PATH/example.com/orderers/example.com

mkdir -p $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com

echo
echo "## Generate the orderer msp"
echo
set -x
fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/msp --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles $TLS_CERT_FILE
set +x

cp $ORGANIZATION_FOLDER_PATH/example.com/msp/config.yaml $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/msp/config.yaml

echo
echo "## Generate the orderer-tls certificates"
echo
set -x
fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/tls --enrollment.profile tls --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles $TLS_CERT_FILE
set +x

cp $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/tls/tlscacerts/* $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/tls/ca.crt
cp $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/tls/signcerts/* $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/tls/server.crt
cp $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/tls/keystore/* $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/tls/server.key

mkdir $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/msp/tlscacerts
cp $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/tls/tlscacerts/* $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

mkdir $ORGANIZATION_FOLDER_PATH/example.com/msp/tlscacerts
cp $ORGANIZATION_FOLDER_PATH/example.com/orderers/orderer.example.com/tls/tlscacerts/* $ORGANIZATION_FOLDER_PATH/example.com/msp/tlscacerts/tlsca.example.com-cert.pem

mkdir -p $ORGANIZATION_FOLDER_PATH/example.com/users
mkdir -p $ORGANIZATION_FOLDER_PATH/example.com/users/Admin@example.com

echo
echo "## Generate the admin msp"
echo
set -x
fabric-ca-client enroll -u https://ordererAdmin:ordererAdminpw@localhost:9054 --caname ca-orderer -M $ORGANIZATION_FOLDER_PATH/example.com/users/Admin@example.com/msp --tls.certfiles $TLS_CERT_FILE
set +x

cp $ORGANIZATION_FOLDER_PATH/example.com/msp/config.yaml $ORGANIZATION_FOLDER_PATH/example.com/users/Admin@example.com/msp/config.yaml
