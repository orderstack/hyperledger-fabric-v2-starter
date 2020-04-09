# HyperLedger Sample With Off Chain Data Synchronization

This sample demonstrates how you can use [Peer channel-based event services](https://hyperledger-fabric.readthedocs.io/en/release-2.0/peer_event_services.html) to replicate the data on your blockchain network to an off chain database.
Using an off chain database allows you to analyze the data from your network or build a dashboard without degrading the performance of your application.

Also this example demonstrates the creation of a single organization network and also
allows you to add more organizations if needed.

This sample uses the [Fabric network event listener](https://hyperledger.github.io/fabric-sdk-node/release-1.4/tutorial-channel-events.html) from the Node.JS Fabric SDK to write data to local instance of CouchDB.

## Getting started

Use the following command to initialize the hyperledger fabric binaries and docker images from the hyperledger repository

```
./init.sh
```

This command will download all the binaries for hyperledger fabric and related configs

This sample uses Node Fabric SDK application code similar to connect to a running instance of the Fabric test network. Make sure that you are running the following commands from the `network/scripts` directory for now.

### Starting the Network

Use the following command to start the sample network:

```
./network.sh up createChannel -ca
```

This command will deploy an instance of the Fabric test network. The network consists of an ordering service, one peer organization, and a CA for the org. The command also creates a channel named `mychannel`.

### Installing the Chaincode

```
./deployCCSingleOrg.sh
```

This command packages the marbles chaincode and then the marbles chaincode will be installed on the peer and deployed to the channel.

### Testing the Chaincode

```
./testCCSingleOrg.sh
```

This command will create a marble called `marble5555` and try to read the marble data which has been commited to the chaincode.

The following should be the output

```
Using organization 1
Using organization 1
2020-04-09 17:22:52.587 IST [chaincodeCmd] chaincodeInvokeOrQuery -> INFO 001 Chaincode invoke successful. result: status:200
waiting for chaincode to reflect
2020-04-09 17:23:02.718 IST [chaincodeCmd] chaincodeInvokeOrQuery -> INFO 001 Chaincode invoke successful. result: status:200 payload:"{\"color\":\"blue\",\"docType\":\"marble\",\"name\":\"marble555\",\"owner\":\"tom\",\"size\":35}"
```

### Configuration

The configuration for the listener is stored in the `network/code/config.json` file:

```
{
	"peer_name": "peer0.org1.example.com",
	"channelid": "mychannel",
	"use_couchdb": true,
	"create_history_log": true,
	"couchdb_address": "http://admin:password@localhost:5984"
}
```

`peer_name:` is the target peer for the listener.
`channelid:` is the channel name for block events.
`use_couchdb:` If set to true, events will be stored in a local instance of CouchDB. If set to false, only a local log of events will be stored.
`create_history_log:` If true, a local log file will be created with all of the block changes.
`couchdb_address:` is the local address for an off chain CouchDB database.

### Starting the Channel Event Listener

If you set the "use_couchdb" option to true in `network/code/config.json`, you can run the following command to initialize the couch instance and a few more dependencies.

**Note:** This command needs to be executed from the `network/code` directory

```
./offChainInit.sh
```

This will run a series of commands

```
# Following command start a local instance of CouchDB using docker
docker run -e COUCHDB_USER=admin -e COUCHDB_PASSWORD=password --publish 5990:5984 --detach --name offchaindb couchdb
docker start offchaindb

# You need to install Node.js version 8.9.x to use the sample application code.
# Following command to install the required dependencies:
npm install

# After we have installed the application dependencies, we can use the Node.js SDK
# to create the identity our listener application will use to interact with the
# network. Following command is executed to enroll the admin user
node enrollAdmin.js

# Following command to register and enroll an application user
node registerUser.js

# Then we can then use our application user to start the block event listener
node blockEventListener.js
```

If the command is successful, you should see the output of the listener reading the configuration blocks of `mychannel` in addition to the blocks that recorded the approval and commitment of the marbles chaincode definition.

```
Listening for block events, nextblock: 0
Added block 0 to ProcessingMap
Added block 1 to ProcessingMap
Added block 2 to ProcessingMap
Added block 3 to ProcessingMap
Added block 4 to ProcessingMap
Added block 5 to ProcessingMap
Added block 6 to ProcessingMap
------------------------------------------------
Block Number: 0
------------------------------------------------
Block Number: 1
------------------------------------------------
Block Number: 2
------------------------------------------------
Block Number: 3
Block Timestamp: 2019-08-08T19:47:56.148Z
ChaincodeID: _lifecycle
[]
------------------------------------------------
...
...
```

`blockEventListener.js` creates a listener named "offchain-listener" on thechannel `mychannel`. The listener writes each block added to the channel to a processing map called BlockMap for temporary storage and ordering purposes.
`blockEventListener.js` uses `nextblock.txt` to keep track of the latest block that was retrieved by the listener. The block number in `nextblock.txt` may be set to a previous block number in order to replay previous blocks. The file may also be deleted and all blocks will be replayed when the block listener is started.

`BlockProcessing.js` runs as a daemon and pulls each block in order from the BlockMap. It then uses the read-write set of that block to extract the latest key value data and store it in the database. The configuration blocks of mychannel did not any data to the database because the blocks did not contain a read-write set.

The channel event listener also writes metadata from each block to a log file defined as channelid_chaincodeid.log. In this example, events will be written to a file named `mychannel_marbles.log`. This allows you to record a history of changes made by each block for each key in addition to storing the latest value of the world state.

**Note:** Leave the blockEventListener.js running in a terminal window. Open a new window to execute the next parts of the starter.

### Generate data on the blockchain

Now that our listener is setup, we can generate data using the marbles chaincode and use our application to replicate the data to our database. Open a new terminal and navigate to the `network/code` directory.

You can use the `addMarbles.js` file to add random sample data to blockchain. The file uses the configuration information stored in `addMarbles.json` to create a series of marbles. This file will be created during the first execution of `addMarbles.js` if it does not exist. This program can be run multiple times without changing the properties. The `nextMarbleNumber` will be incremented and stored in the `addMarbles.json` file.

```
    {
        "nextMarbleNumber": 100,
        "numberMarblesToAdd": 20
    }
```

Open a new window and run the following command to add 20 marbles to the
blockchain:

```
node addMarbles.js
```

After the marbles have been added to the ledger, use the following command to
transfer one of the marbles to a new owner:

```
node transferMarble.js marble110 james
```

Now run the following command to delete the marble that was transferred:

```
node deleteMarble.js marble110
```

## Offchain CouchDB storage:

If you followed the instructions above and set `use_couchdb` to true, `blockEventListener.js` will create two tables in the local instance of CouchDB. `blockEventListener.js` is written to create two tables for each channel and for each chaincode.

The first table is an offline representation of the current world state of the blockchain ledger. This table was created using the read-write set data from the blocks. If the listener is running, this table should be the same as the latest values in the state database running on your peer. The table is named after the channelid and chaincodeid, and is named mychannel_marbles in this example. You can navigate to this table using your browser: http://127.0.0.1:5984/mychannel_marbles/_all_docs

## Clean up

**Note:** This command needs to be executed from the `network/scripts` directory

If you are finished using the sample application, you can bring down the network
and any accompanying artifacts by running the following command:

```
./network.sh down
```

Running the script will complete the following actions:

-   Bring down the Fabric test network.
-   Takes down the local CouchDB database.
-   Remove the certificates you generated by deleting the `network/code/wallet` folder.
-   Delete `network/code/nextblock.txt` so you can start with the first block next time you
    operate the listener.
-   Removes `network/code/addMarbles.json`.
