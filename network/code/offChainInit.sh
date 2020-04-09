docker run -e COUCHDB_USER=admin -e COUCHDB_PASSWORD=password --publish 5990:5984 --detach --name offchaindb couchdb
docker start offchaindb
npm install
node enrollAdmin.js
node registerUser.js
node blockEventListener.js