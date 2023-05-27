#!/bin/bash

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
mkdir -p $tmp_dir
mkdir -p ./dist/bootnode-keys

function add_bootnode_enr() {
  echo "$1" >> ./dist/bootstrap_nodes.txt
  echo "- $1" >> ./dist/boot_enr.txt
}

function Bootnodes() {
  bootnode_name="$1"
  bootnode_keyfile="$2"
  bootnode_pubkey="${bootnode_name}.pub"
  if [ -f ./bootnode-keys/$bootnode_pubkey ]; then
    openssl pkeyutl -encrypt -inkey ./bootnode-keys/$bootnode_pubkey -pubin -in $bootnode_keyfile -out ./dist/bootnode-keys/${bootnode_name}.key.enc
  fi
}

Bootnodes
add_bootnode_enr