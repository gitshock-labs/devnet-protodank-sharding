#!bin/bash

identity=Gitshock-GIP4844

function geth() {
    nohup geth \
	  --http \
	  --http.port 8545 \
	  --http.api=eth,net,web3,admin,engine \
	  --http.addr=0.0.0.0 \
	  --http.vhosts=* \
	  --http.corsdomain=* \
	  --ws \
	  --ws.api "eth,net,web3,admin,engine" \
	  --ws.addr=0.0.0.0 \
	  --ws.port 8557 \
	  --identity "$identity" \
	  --light.maxpeers 30 \
	  --bloomfilter.size 2048 \
	  --cache 1024 \
	  --gcmode="archive" \
	  --networkid 1881 \
	  --datadir "/home/admin/eth-generator/data/geth-data" \
	  --authrpc.port 8551  \
	  --port 30303 \
	  --discovery.port 30303 \
	  --verbosity 3 \
	  --syncmode full \
	  --allow-insecure-unlock \
	  --unlock "0x9999995993dd7eafd2753A4c7E35c2354B112036" \
	  --password "/home/admin/eth-generator/data/geth-data/keystore/password.txt" \
	  > /home/admin/eth-generator/data/log/geth.log &
}
function beacon() {
    nohup lighthouse beacon \
	  --http \
	  --eth1 \
	  --http-address "127.0.0.1" \
	  --http-allow-sync-stalled \
	  --execution-endpoints "http://127.0.0.1:8551" \
	  --http-port=5052 \
	  --enr-udp-port=9000 \
	  --enr-tcp-port=9000 \
	  --discovery-port=9000 \
	  --port=9000 \
	  --metrics-allow-origin="*" \
	  --metrics \
	  --metrics-address "127.0.0.1" \
	  --metrics-port 5054 \
	  --testnet-dir "/home/admin/eth-generator/data/config_data" \
	  --datadir "/home/admin/eth-generator/data/beacon-data" \
	  --jwt-secrets="/home/admin/eth-generator/data/geth-data/geth/jwtsecret" \
	  --boot-nodes="enr:-Ly4QOlgr3GCatU8b_VpHSmeidjByL7snKah73AfOWdwkHnqVsLBcQm_MYg8tWHD2a8BNBRWtO9_BsuK24Th6BLJi_UCh2F0dG5ldHOIAAAAAAAAAACEZXRoMpC7pNqWAwAAAP__________gmlkgnY0gmlwhDIQX6-Jc2VjcDI1NmsxoQMw--YVJhcIiMquVS2A7Dt9ZlytkuDOvAUj-ohx7x8XBIhzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA" \
	  --suggested-fee-recipient "0x2BC6649aaA5bd67b25B6519Ac50A6305Ce66B7D3" \
	  > /home/admin/eth-generator/data/log/beacon.log &
}

function beacon2() {
	nohup lighthouse beacon \
	  --http \
	  --eth1 \
	  --http-address "127.0.0.1" \
	  --http-allow-sync-stalled \
	  --execution-endpoints "http://127.0.0.1:8551" \
	  --http-port=5053 \
	  --enr-udp-port=9002 \
	  --enr-tcp-port=9002 \
	  --discovery-port=9002 \
	  --port=9002 \
	  --metrics-allow-origin="*" \
	  --metrics \
	  --metrics-address "127.0.0.1" \
	  --metrics-port 5055 \
	  --testnet-dir "/home/admin/eth-generator/data/config_data" \
	  --datadir "/home/admin/eth-generator/data/beacon-data-2" \
	  --jwt-secrets="/home/admin/eth-generator/data/geth-data/geth/jwtsecret" \
	  --boot-nodes="enr:-Ly4QOlgr3GCatU8b_VpHSmeidjByL7snKah73AfOWdwkHnqVsLBcQm_MYg8tWHD2a8BNBRWtO9_BsuK24Th6BLJi_UCh2F0dG5ldHOIAAAAAAAAAACEZXRoMpC7pNqWAwAAAP__________gmlkgnY0gmlwhDIQX6-Jc2VjcDI1NmsxoQMw--YVJhcIiMquVS2A7Dt9ZlytkuDOvAUj-ohx7x8XBIhzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA,enr:-LS4QJu4r75igHKERnNJ1mhMu7kc12lRfkIHlFLEUrxSrbFZZOLiUEdQxptFB4fU8_eRF8OA5WznFoLel5JtEduiQJkBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBOD_4PQAAYgRAnAAAAAAAAgmlkgnY0iXNlY3AyNTZrMaED3UOnS23zxq961werjhFZJxclvYJ5oo4gV_MwHvRbFJWIc3luY25ldHMAg3RjcIIjKIN1ZHCCIyg" \
	  --suggested-fee-recipient "0x2BC6649aaA5bd67b25B6519Ac50A6305Ce66B7D3" \
	  > /home/admin/eth-generator/data/log/beacon-2.log &
}

function validatorImport() {
	lighthouse account validator import \
	  --testnet-dir "/home/admin/eth-generator/data/config_data" \
	  --datadir  /home/admin/eth-generator/data/validator-node \
	  --directory /home/admin/eth-generator/data/validator-data/validator_keys \
	  --password-file /home/admin/eth-generator/data/validator-data/validator_keys/password.txt \
	  --reuse-password
}

function validator() {
	nohup lighthouse vc \
	  --http \
	  --unencrypted-http-transport \
	  --http-allow-origin="*" \
	  --http-port 5062 \
	  --http-address 127.0.0.1 \
	  --metrics \
	  --metrics-address "127.0.0.1" \
	  --metrics-port 5059 \
	  --metrics-allow-origin="*" \
	  --datadir "/home/admin/eth-generator/data/validator-node" \
	  --testnet-dir "/home/admin/eth-generator/data/config_data" \
	  --suggested-fee-recipient "0x2BC6649aaA5bd67b25B6519Ac50A6305Ce66B7D3" \
	  --graffiti "Devnet-Gitshock" \
	  --beacon-nodes "http://127.0.0.1:5053" \
	 > /home/admin/eth-generator/data/log/validator.log &
}


geth
beacon
beacon2
validatorImport
validator