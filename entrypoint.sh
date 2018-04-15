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

# binary daemon
DAEMOND=/usr/bin/niobiod

# walletd conf
WALLETD_DATA=/niobio
WALLETD_LOG=$WALLETD_DATA/walletd.log
NEWWALLET_LOG=$WALLETD_DATA/newwallet.log
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

# daemon conf
DAEMON_DATA=$WALLETD_DATA
DAEMON_LOG=$DAEMON_DATA/niobiod.log
DAEMON_P2P_ADDRESS="0.0.0.0"
DAEMON_P2P_PORT="30264"
DAEMON_RPC_ADDRESS="0.0.0.0"
DAEMON_RPC_PORT="40264"

# load secret file with contains wallet address and password
[ -f $WALLETD_KEY ] && . $WALLETD_KEY

# validate if wallet exists
if [ ! -f $WALLETD_FILE ]; then

  # generate a new password
  WALLETD_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

  # generate a new wallet
  $WALLETD -w $WALLETD_FILE -p $WALLETD_PASSWORD -l $NEWWALLET_LOG -g 2>&1 >/dev/null

  # make backup of original file
  cp --preserve $WALLETD_FILE $WALLETD_DATA/walletdb.wallet

fi

# get address from wallet
declare -a WALLETD_GET_PARAMS
WALLETD_GET_PARAMS[0]="--container-file $WALLETD_FILE"
WALLETD_GET_PARAMS[1]="--container-password $WALLETD_PASSWORD"
WALLETD_GET_PARAMS[2]="--log-file /dev/null"
WALLETD_GET_PARAMS[3]="--address"
WALLETD_GET_PARAMS[4]="--log-level 0"
WALLETD_PUBLIC_ADDRESS=$($WALLETD ${WALLETD_GET_PARAMS[*]} | grep -i "address" | head -n1 | cut -d':' -f2 | tr -d ' ')

# update key file
echo -n > $WALLETD_KEY
echo "WALLETD_PUBLIC_ADDRESS=$WALLETD_PUBLIC_ADDRESS" > $WALLETD_KEY
echo "WALLETD_PASSWORD=$WALLETD_PASSWORD" >> $WALLETD_KEY

# reload key file
. $WALLETD_KEY

# make command options for daemon
declare -a DAEMON_RUN_PARAMS
DAEMON_RUN_PARAMS[0]="--data-dir $DAEMON_DATA"
DAEMON_RUN_PARAMS[1]="--enable-blockchain-indexes"
DAEMON_RUN_PARAMS[2]="--restricted-rpc"
DAEMON_RUN_PARAMS[3]="--log-file $DAEMON_LOG"
DAEMON_RUN_PARAMS[4]="--p2p-bind-ip $DAEMON_P2P_ADDRESS"
DAEMON_RUN_PARAMS[5]="--p2p-bind-port $DAEMON_P2P_PORT"
DAEMON_RUN_PARAMS[6]="--rpc-bind-ip $DAEMON_RPC_ADDRESS"
DAEMON_RUN_PARAMS[7]="--rpc-bind-port $DAEMON_RPC_PORT"
DAEMON_RUN_PARAMS[8]="--fee-address $WALLETD_PUBLIC_ADDRESS"
DAEMON_RUN_PARAMS[9]="--hide-my-port"
DAEMON_RUN_PARAMS[10]="--testnet"
DAEMON_RUN_PARAMS[11]="--no-console"

# make command options for walletd
declare -a WALLETD_RUN_PARAMS
WALLETD_RUN_PARAMS[0]="--container-file $WALLETD_FILE"
WALLETD_RUN_PARAMS[1]="--container-password $WALLETD_PASSWORD"
WALLETD_RUN_PARAMS[2]="--log-file $WALLETD_LOG"
WALLETD_RUN_PARAMS[3]="--data-dir $WALLETD_DATA"
WALLETD_RUN_PARAMS[4]="--bind-address $WALLETD_BIND_ADDRESS"
WALLETD_RUN_PARAMS[5]="--bind-port $WALLETD_BIND_PORT"
WALLETD_RUN_PARAMS[6]="--hide-my-port"

# is testnet ?
if bool "$TESTNET"; then
  WALLETD_RUN_PARAMS[7]="--testnet"
  WALLETD_DAEMON_ADDRESS=$DAEMON_RPC_ADDRESS
  WALLETD_DAEMON_PORT=$DAEMON_RPC_PORT
fi

# have daemon informed ?
if [ ! -z "$WALLETD_DAEMON_ADDRESS" ]; then
  WALLETD_RUN_PARAMS[8]="--daemon-address $WALLETD_DAEMON_ADDRESS"
  WALLETD_RUN_PARAMS[9]="--daemon-port $WALLETD_DAEMON_PORT"
else
  WALLETD_RUN_PARAMS[10]="--local"
fi

# start process
bool "$TESTNET" && $DAEMOND ${DAEMON_RUN_PARAMS[*]} 2>&1 >/dev/null &
$WALLETD ${WALLETD_RUN_PARAMS[*]} 2>&1 >/dev/null
