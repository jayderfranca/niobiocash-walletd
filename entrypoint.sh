#!/bin/bash -em

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

# supervisord file configuration
SUPERVISORD_CONF=/etc/supervisord.conf

# binary walletd
WALLETD=/usr/bin/walletd

# binary daemon
DAEMONL=/usr/bin/niobiod

# walletd conf
WALLETD_DATA=/niobio
WALLETD_LOG=$WALLETD_DATA/walletd.log
NEWWALLET_LOG=$WALLETD_DATA/newwallet.log
WALLETD_KEY=$WALLETD_DATA/walletd.key
WALLETD_FILE=$WALLETD_DATA/walletd.wallet
WALLETD_TESTNET=$TESTNET
WALLETD_BIND_ADDRESS="0.0.0.0"
WALLETD_BIND_PORT="20264"
WALLETD_DAEMONR_ADDRESS=$(echo "$DAEMON" | cut -d':' -f1)
WALLETD_DAEMONR_PORT=$(echo "$DAEMON" | cut -d':' -f2)
WALLETD_DAEMONR_PORT=${WALLETD_DAEMONR_PORT:-"8314"}

# daemon conf
DAEMONL_DATA=$WALLETD_DATA
DAEMONL_LOG=$DAEMONL_DATA/niobiod.log
DAEMONL_P2P_ADDRESS="0.0.0.0"
DAEMONL_P2P_PORT="30264"
DAEMONL_RPC_ADDRESS="0.0.0.0"
DAEMONL_RPC_PORT="40264"

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

# dont show password on command line
echo "container-file=$WALLETD_FILE" > $WALLETD_DATA/walletd.conf
echo "container-password=$WALLETD_PASSWORD" >> $WALLETD_DATA/walletd.conf

# get address from wallet
declare -a WALLETD_GET_PARAMS
WALLETD_GET_PARAMS[0]="--config $WALLETD_DATA/walletd.conf"
WALLETD_GET_PARAMS[1]="--log-file /dev/null"
WALLETD_GET_PARAMS[2]="--address"
WALLETD_GET_PARAMS[3]="--log-level 0"
WALLETD_PUBLIC_ADDRESS=$($WALLETD ${WALLETD_GET_PARAMS[*]} | grep -i "address" | head -n1 | cut -d':' -f2 | tr -d ' ')

# update key file
echo -n > $WALLETD_KEY
echo "WALLETD_PUBLIC_ADDRESS=$WALLETD_PUBLIC_ADDRESS" > $WALLETD_KEY
echo "WALLETD_PASSWORD=$WALLETD_PASSWORD" >> $WALLETD_KEY

# reload key file
. $WALLETD_KEY

# make command options for daemon
declare -a DAEMONL_RUN_PARAMS
DAEMONL_RUN_PARAMS[0]="--data-dir $DAEMONL_DATA"
DAEMONL_RUN_PARAMS[1]="--enable-blockchain-indexes"
DAEMONL_RUN_PARAMS[2]="--restricted-rpc"
DAEMONL_RUN_PARAMS[3]="--log-file $DAEMONL_LOG"
DAEMONL_RUN_PARAMS[4]="--p2p-bind-ip $DAEMONL_P2P_ADDRESS"
DAEMONL_RUN_PARAMS[5]="--p2p-bind-port $DAEMONL_P2P_PORT"
DAEMONL_RUN_PARAMS[6]="--rpc-bind-ip $DAEMONL_RPC_ADDRESS"
DAEMONL_RUN_PARAMS[7]="--rpc-bind-port $DAEMONL_RPC_PORT"
DAEMONL_RUN_PARAMS[8]="--fee-address $WALLETD_PUBLIC_ADDRESS"
DAEMONL_RUN_PARAMS[9]="--hide-my-port"
DAEMONL_RUN_PARAMS[10]="--testnet"
DAEMONL_RUN_PARAMS[11]="--no-console"

# make command options for walletd
declare -a WALLETD_RUN_PARAMS
WALLETD_RUN_PARAMS[0]="--config $WALLETD_DATA/walletd.conf"
WALLETD_RUN_PARAMS[1]="--log-file $WALLETD_LOG"
WALLETD_RUN_PARAMS[2]="--data-dir $WALLETD_DATA"
WALLETD_RUN_PARAMS[3]="--bind-address $WALLETD_BIND_ADDRESS"
WALLETD_RUN_PARAMS[4]="--bind-port $WALLETD_BIND_PORT"
WALLETD_RUN_PARAMS[5]="--hide-my-port"

# is testnet ?
if bool "$TESTNET"; then
  WALLETD_RUN_PARAMS[6]="--testnet"
  WALLETD_DAEMONR_ADDRESS=$DAEMONL_RPC_ADDRESS
  WALLETD_DAEMONR_PORT=$DAEMONL_RPC_PORT
fi

# have daemon informed ?
if [ ! -z "$WALLETD_DAEMONR_ADDRESS" ]; then
  WALLETD_RUN_PARAMS[7]="--daemon-address $WALLETD_DAEMONR_ADDRESS"
  WALLETD_RUN_PARAMS[8]="--daemon-port $WALLETD_DAEMONR_PORT"
else
  WALLETD_RUN_PARAMS[9]="--local"
  WALLETD_RUN_PARAMS[10]="--p2p-bind-ip $DAEMONL_P2P_ADDRESS"
  WALLETD_RUN_PARAMS[11]="--p2p-bind-port $DAEMONL_P2P_PORT"
fi

# create directory for logging - supervisord
mkdir -p /var/log/supervisord

# create directory for logging - walletd and daemon
mkdir -p $WALLETD_DATA/console

# create supervisord configuration
cat <<EOF >> $SUPERVISORD_CONF
[unix_http_server]
file=/tmp/supervisor.sock

[supervisord]
logfile=/var/log/supervisord/supervisord.log
logfile_maxbytes=50MB
logfile_backups=10
loglevel=error
pidfile=/var/run/supervisord.pid
minfds=1024
minprocs=200
user=root
childlogdir=/var/log/supervisord/

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock

[program:walletd]
command=$WALLETD ${WALLETD_RUN_PARAMS[*]}
directory=$WALLETD_DATA
autostart=true
autorestart=true
stderr_logfile=$WALLETD_DATA/console/walletd.errors.log
stdout_logfile=$WALLETD_DATA/console/walletd.output.log
priority=200
EOF

# if is testnet, create a local daemon
if bool "$TESTNET"; then
  echo "" >> $SUPERVISORD_CONF
  echo "[program:DAEMONL]" >> $SUPERVISORD_CONF
  echo "command=$DAEMONL ${DAEMONL_RUN_PARAMS[*]}" >> $SUPERVISORD_CONF
  echo "directory=$DAEMONL_DATA" >> $SUPERVISORD_CONF
  echo "autostart=true" >> $SUPERVISORD_CONF
  echo "autorestart=true" >> $SUPERVISORD_CONF
  echo "stderr_logfile=$DAEMONL_DATA/console/niobiod.errors.log" >> $SUPERVISORD_CONF
  echo "stdout_logfile=$DAEMONL_DATA/console/niobiod.output.log" >> $SUPERVISORD_CONF
  echo "priority=100" >> $SUPERVISORD_CONF
fi

# start supervisord
if [ ! -z "$1" ]; then
  /usr/local/bin/supervisord --configuration $SUPERVISORD_CONF
  exec "$@"
else
  /usr/local/bin/supervisord --nodaemon --configuration $SUPERVISORD_CONF
fi
