#!/bin/bash

# parse value to boolean
# if cannot parse, return false
function bool() {
  value="${1,,}"
  if [[ "y yes true 0" =~ (^|[[:space:]])$value($|[[:space:]]) ]]; then
    return 0
  else
    return 1
  fi
}

# binary walletd
WALLETD=/usr/bin/walletd

# data directory walletd
WALLETD_DATA=/niobio

# log file
WALLETD_LOG=$WALLETD_DATA/walletd.log
NEWWALLET_LOG=$WALLETD_DATA/newwallet.log

# others variables
WALLETD_KEY=$WALLETD_DATA/walletd.key
WALLETD_FILE=$WALLETD_DATA/walletd.wallet
WALLETD_TESTNET=$TESTNET
WALLETD_BIND_ADDRESS=$(echo "$BIND" | cut -d':' -f1)
WALLETD_BIND_ADDRESS=${WALLETD_BIND_ADDRESS:-"0.0.0.0"}
WALLETD_BIND_PORT=$(echo "$BIND" | cut -d':' -f2)
WALLETD_BIND_PORT=${WALLETD_BIND_PORT:-"20264"}
WALLETD_DAEMON_ADDRESS=$(echo "$DAEMON" | cut -d':' -f1)
WALLETD_DAEMON_PORT=$(echo "$DAEMON" | cut -d':' -f2)
WALLETD_DAEMON_PORT=${WALLETD_DAEMON_PORT:-"8314"}

# load secret file with contains wallet address and password
[ -f $WALLETD_KEY ] && . $WALLETD_KEY

# validate if wallet exists
if [ ! -f $WALLETD_FILE ]; then

  # generate a new password
  WALLETD_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

  # generate a new wallet
  $WALLETD -w $WALLETD_FILE -p $WALLETD_PASSWORD -l $NEWWALLET_LOG -g 2>&1 >/dev/null

  # make backup of original file
  cp --preserve $WALLETD_FILE $WALLETD_DATA/walletd.orig.wallet

fi

# get address from wallet
declare -a GET_CMDPARAMS
GET_CMDPARAMS[0]="--container-file $WALLETD_FILE"
GET_CMDPARAMS[1]="--container-password $WALLETD_PASSWORD"
GET_CMDPARAMS[2]="--log-file /dev/null"
GET_CMDPARAMS[3]="--address"
GET_CMDPARAMS[4]="--log-level 0"
WALLETD_PUBLIC_ADDRESS=$($WALLETD ${GET_CMDPARAMS[*]} | grep -i "address" | head -n1 | cut -d':' -f2 | tr -d ' ')

# update key file
echo -n > $WALLETD_KEY
echo "WALLETD_PUBLIC_ADDRESS=$WALLETD_PUBLIC_ADDRESS" > $WALLETD_KEY
echo "WALLETD_PASSWORD=$WALLETD_PASSWORD" >> $WALLETD_KEY

# reload key file
. $WALLETD_KEY

# make command options
declare -a CMDPARAMS
RUN_CMDPARAMS[0]="--container-file $WALLETD_FILE"
RUN_CMDPARAMS[1]="--container-password $WALLETD_PASSWORD"
RUN_CMDPARAMS[2]="--log-file $WALLETD_LOG"
RUN_CMDPARAMS[3]="--data-dir $WALLETD_DATA"
RUN_CMDPARAMS[4]="--bind-address $WALLETD_BIND_ADDRESS"
RUN_CMDPARAMS[5]="--bind-port $WALLETD_BIND_PORT"
RUN_CMDPARAMS[6]="--hide-my-port"

# is testnet ?
bool "$TESTNET" && RUN_CMDPARAMS[7]="--testnet"

# have remote daemon ?
if [ ! -z "$WALLETD_DAEMON_ADDRESS" ]; then
  RUN_CMDPARAMS[8]="--daemon-address $WALLETD_DAEMON_ADDRESS"
  RUN_CMDPARAMS[9]="--daemon-port $WALLETD_DAEMON_PORT"
else
  RUN_CMDPARAMS[10]="--local"
fi

# start process
$WALLETD ${RUN_CMDPARAMS[*]} 2>&1 >/dev/null
