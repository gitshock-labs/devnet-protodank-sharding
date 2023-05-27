#!/bin/bash

######## Checker Functions
LogLevel=info
accounts=0xe1c48db7850575e1c2092476d5122d0d868c017c

function Log() {
	echo
	echo "--> $1"
}
function CheckGeth()
{
	Log "Checking Geth"
	test -z $my_ip && my_ip=`curl ifconfig.me 2>/dev/null` && Log "my_ip=$my_ip"
	geth attach --exec "admin.nodeInfo.enode" /home/ubuntu/k8s-devnet/execution/geth-data/geth.ipc | sed s/^\"// | sed s/\"$//
	echo Peers: `geth attach --exec "admin.peers" /home/ubuntu/k8s-devnet/execution/geth-data/geth.ipc | grep "remoteAddress" | grep -e $my_ip -e "127.0.0.1"`
	echo Block Number: `geth attach --exec "eth.blockNumber" /home/ubuntu/k8s-devnet/execution/geth-data/geth.ipc`
}
function CheckBeacon()
{
	Log "Checking Beacon $1"
	echo My ID: `curl http://localhost:5052/eth/v1/node/identity 2>/dev/null | jq -r ".data.peer_id"`
	echo My enr: `curl http://localhost:5052/eth/v1/node/identity 2>/dev/null | jq -r ".data.enr"`
	echo Peer Count: `curl http://localhost:5052/eth/v1/node/peers 2>/dev/null | jq -r ".meta.count"`
	curl http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq
}

function KillAll() {
	Log "Kill All Apps"
	killall geth
	pkill -f lighthouse
}
function PrepareEnvironment() {
	Log "Cleaning Environment"
	KillAll

	git clean -fxd
	rm execution/bootnodes.txt consensus/bootnodes.txt
	
	my_ip=`curl ifconfig.me 2>/dev/null` && Log "my_ip=$my_ip"
}
function AdjustTimestamps {
	timestamp=`date +%s`	
	timestampHex=`printf '%x' $timestamp`
	Log "timestamp=$timestamp"
	Log "timestampHex=$timestampHex"

	sed -i s/\"timestamp\":.*/\"timestamp\":\"0x$timestampHex\",/g custom_config_data/genesis.json
	sed -i s/MIN_GENESIS_TIME:.*/"MIN_GENESIS_TIME: $timestamp"/g custom_config_data/config.yaml
}
function InitGeth()
{
	Log "Initializing geth $1"
	geth init \
	  --datadir "/home/ubuntu/k8s-devnet/execution/geth-data" \
	  /home/ubuntu/k8s-devnet/custom_config_data/genesis.json
}

function RunGeth()
{
	Log "Running Geth on port 8551"
	local bootnodes=$(cat execution/bootnodes.txt 2>/dev/null | tr '\n' ',' | sed s/,$//g)
	echo "Geth Bootnodes = $bootnodes"
	nohup geth \
		--http \
		--http.port=8545 \
		--http.api eth,net,web3,personal,admin,txpool \
		--http.addr=0.0.0.0 \
		--http.vhosts=* \
		--http.corsdomain=* \
		--networkid 1881 \
		--datadir "/home/ubuntu/k8s-devnet/execution/geth-data" \
		--authrpc.port 8551 \
		--port 30303 \
		--syncmode full \
		--identity "gitshock-devnet" \
		--cache 1024 \
		--cache.blocklogs 32 \
		--cache.database 50 \
		--cache.gc 25 \
		--cache.trie 15 \
		--txpool.globalslots 5120 \
		--metrics \
		--metrics.influxdb \
		--metrics.influxdb.endpoint "http://0.0.0.0:8086" \
		--metrics.influxdb.username "jakartafork" \
		--metrics.influxdb.password "jakartafork" \
		--log.maxage 5 \
		--log.maxbackups 10 \
		--log.vmodule "eth/*3, p2p=3" \
		--verbosity 3 \
		--log.maxage 5 \
		--log.maxbackups 10 \
		--log.vmodule "eth/*3, p2p=3" \
		--verbosity 3 \
		--bootnodes=$bootnodes \
		> /home/ubuntu/k8s-devnet/logs/geth.log &
		sleep 5  # set to 5 seconds to allow the geth to bind to the external IP before reading enode

		# grab bootnode from attach geth-ethereum
		local my_enode=$(geth attach --exec "admin.nodeInfo.enode" /home/ubuntu/k8s-devnet/execution/geth-data/geth.ipc | sed s/^\"// | sed s/\"$// | sed s/'127.0.0.1'/$my_ip/)
	    echo $my_enode >> execution/bootnodes.txt
}
function StoreGethHash() {
	genesis_hash=`geth attach --exec "eth.getBlockByNumber(0).hash" /home/ubuntu/k8s-devnet/execution/geth-data/geth.ipc | sed s/^\"// | sed s/\"$//`

	echo $genesis_hash > /home/ubuntu/k8s-devnet/custom_config_data/deposit_contract_block_hash.txt
	echo $genesis_hash > /home/ubuntu/k8s-devnet/custom_config_data/deposit_contract_block.txt
	sed -i s/TERMINAL_BLOCK_HASH:.*/"TERMINAL_BLOCK_HASH: $genesis_hash"/g /home/ubuntu/k8s-devnet/custom_config_data/config.yaml
	cat /home/ubuntu/k8s-devnet/custom_config_data/config.yaml|grep TERMINAL_BLOCK_HASH
	Log "genesis_hash = $genesis_hash"
}
function GenerateGenesisSSZ()
{
	Log "Generating Beaconchain Genesis"
	eth2-testnet-genesis merge \
	  --config "/home/ubuntu/k8s-devnet/custom_config_data/config.yaml" \
	  --eth1-config "/home/ubuntu/k8s-devnet/custom_config_data/genesis.json" \
	  --mnemonics "/home/ubuntu/k8s-devnet/custom_config_data/mnemonics.yaml" \
	  --state-output "/home/ubuntu/k8s-devnet/custom_config_data/genesis.ssz" \
	  --tranches-dir "/home/ubuntu/k8s-devnet/custom_config_data/tranches"
}
function ImportVC() {
	  lighthouse account validator import \
	  --testnet-dir /home/ubuntu/k8s-devnet/custom_config_data \
	  --datadir "/home/ubuntu/k8s-devnet/consensus/validator" \
	  --directory /home/ubuntu/staking-cli/validator_keys \
	  --password-file /home/ubuntu/staking-cli/validator_keys/password.txt \
	  --reuse-password
}
function RunBeacon() {
	  Log "Running Beacon"
	  local bootnodes=`cat consensus/bootnodes.txt 2>/dev/null | grep . | tr '\n' ',' | sed s/,$//g`
	  echo "Beacon Bootnodes = $bootnodes"
	  
      nohup lighthouse \
	  --testnet-dir "/home/ubuntu/k8s-devnet/custom_config_data" \
	  bn \
	  --datadir "/home/ubuntu/k8s-devnet/consensus/" \
	  --eth1 \
	  --http \
 	  --staking \
	  --http-allow-sync-stalled \
	  --http-allow-origin="*" \
	  --enr-address $my_ip \
	  --execution-endpoints "http://localhost:8551" \
	  --eth1-endpoints "http://localhost:8545" \
	  --http-port 5052 \
	  --port 9000 \
	  --enr-udp-port 9000 \
	  --enr-tcp-port 9000 \
	  --discovery-port 9000 \
	  --logfile-max-number=5 \
	  --jwt-secrets="/home/ubuntu/k8s-devnet/execution/geth-data/geth/jwtsecret" \
	  --boot-nodes=$bootnodes \
	  --suggested-fee-recipient="$accounts" \
	  > /home/ubuntu/k8s-devnet/logs/beacon.log &
	  echo Waiting for Beacon enr ...
	  local my_enr=`curl http://localhost:5052/eth/v1/node/identity 2>/dev/null | jq -r ".data.enr"`
	  while [[ -z $my_enr ]]
	  do
	  	  sleep 1
	  	  local my_enr=`curl http://localhost:5052/eth/v1/node/identity 2>/dev/null | jq -r ".data.enr"`
	  done
	  echo "My Enr = $my_enr"
	  echo $my_enr >> consensus/bootnodes.txt
}
function CheckGeth()
{
	Log "Checking Geth"
	test -z $my_ip && my_ip=`curl ifconfig.me 2>/dev/null` && Log "my_ip=$my_ip"
	geth attach --exec "admin.nodeInfo.enode" /home/ubuntu/k8s-devnet/execution/geth-data/geth.ipc | sed s/^\"// | sed s/\"$//
	echo Peers: `geth attach --exec "admin.peers" /home/ubuntu/k8s-devnet/execution/geth-data/geth.ipc | grep "remoteAddress" | grep -e $my_ip -e "127.0.0.1"`
	echo Block Number: `geth attach --exec "eth.blockNumber" /home/ubuntu/k8s-devnet/execution/geth-data/geth.ipc`
}
function CheckBeacon()
{
	Log "Checking Beacon $1"
	echo My ID: `curl http://localhost:5052/eth/v1/node/identity 2>/dev/null | jq -r ".data.peer_id"`
	echo My enr: `curl http://localhost:5052/eth/v1/node/identity 2>/dev/null | jq -r ".data.enr"`
	echo Peer Count: `curl http://localhost:5052/eth/v1/node/peers 2>/dev/null | jq -r ".meta.count"`
	curl http://localhost:5052/eth/v1/node/syncing 2>/dev/null | jq
}
function RunValidator() {
nohup lighthouse \
  vc \
  --testnet-dir "/home/ubuntu/k8s-devnet/custom_config_data" \
  --datadir "/home/ubuntu/k8s-devnet/consensus/validator" \
  --beacon-nodes http://localhost:5052 \
  --metrics \
  --metrics-address "127.0.0.1" \
  --metrics-port 5062 \
  --logfile-compress \
  --suggested-fee-recipient="$accounts" \
  --graffiti "gitshock-devnet-1" \
  > /home/ubuntu/k8s-devnet/logs/validator.log &
}

KillAll

PrepareEnvironment
set -e
AdjustTimestamps

# Checking All Layers
CheckGeth
CheckBeacon

# Node Execution
InitGeth
RunGeth

# Initialize
StoreGethHash
GenerateGenesisSSZ

# Validator 
RunBeacon


ImportVC
RunValidator

echo "
clear && tail -f logs/geth.log -n1000
clear && tail -f logs/beacon-1.log -n1000
clear && tail -f logs/beacon-2.log -n1000
clear && tail -f logs/validator.log -n1000

curl http://localhost:5053/eth/v1/node/identity | jq
curl http://localhost:5053/eth/v1/node/peers | jq
curl http://localhost:5053/eth/v1/node/syncing | jq
"