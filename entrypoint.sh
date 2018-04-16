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
DAEMOND_DATA=$WALLETD_DATA
DAEMOND_LOG=$DAEMOND_DATA/niobiod.log
DAEMOND_P2P_ADDRESS="0.0.0.0"
DAEMOND_P2P_PORT="30264"
DAEMOND_RPC_ADDRESS="0.0.0.0"
DAEMOND_RPC_PORT="40264"

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
#WALLETD_GET_PARAMS[0]="--container-file $WALLETD_FILE"
WALLETD_GET_PARAMS[1]="--config $WALLETD_DATA/walletd.conf"
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
declare -a DAEMOND_RUN_PARAMS
DAEMOND_RUN_PARAMS[0]="--data-dir $DAEMOND_DATA"
DAEMOND_RUN_PARAMS[1]="--enable-blockchain-indexes"
DAEMOND_RUN_PARAMS[2]="--restricted-rpc"
DAEMOND_RUN_PARAMS[3]="--log-file $DAEMOND_LOG"
DAEMOND_RUN_PARAMS[4]="--p2p-bind-ip $DAEMOND_P2P_ADDRESS"
DAEMOND_RUN_PARAMS[5]="--p2p-bind-port $DAEMOND_P2P_PORT"
DAEMOND_RUN_PARAMS[6]="--rpc-bind-ip $DAEMOND_RPC_ADDRESS"
DAEMOND_RUN_PARAMS[7]="--rpc-bind-port $DAEMOND_RPC_PORT"
DAEMOND_RUN_PARAMS[8]="--fee-address $WALLETD_PUBLIC_ADDRESS"
DAEMOND_RUN_PARAMS[9]="--hide-my-port"
DAEMOND_RUN_PARAMS[10]="--testnet"
DAEMOND_RUN_PARAMS[11]="--no-console"

# make command options for walletd
declare -a WALLETD_RUN_PARAMS
#WALLETD_RUN_PARAMS[0]="--container-file $WALLETD_FILE"
WALLETD_RUN_PARAMS[1]="--config $WALLETD_DATA/walletd.conf"
WALLETD_RUN_PARAMS[2]="--log-file $WALLETD_LOG"
WALLETD_RUN_PARAMS[3]="--data-dir $WALLETD_DATA"
WALLETD_RUN_PARAMS[4]="--bind-address $WALLETD_BIND_ADDRESS"
WALLETD_RUN_PARAMS[5]="--bind-port $WALLETD_BIND_PORT"
WALLETD_RUN_PARAMS[6]="--hide-my-port"

# is testnet ?
if bool "$TESTNET"; then
  WALLETD_RUN_PARAMS[7]="--testnet"
  WALLETD_DAEMON_ADDRESS=$DAEMOND_RPC_ADDRESS
  WALLETD_DAEMON_PORT=$DAEMOND_RPC_PORT
fi

# have daemon informed ?
if [ ! -z "$WALLETD_DAEMON_ADDRESS" ]; then
  WALLETD_RUN_PARAMS[8]="--daemon-address $WALLETD_DAEMON_ADDRESS"
  WALLETD_RUN_PARAMS[9]="--daemon-port $WALLETD_DAEMON_PORT"
else
  WALLETD_RUN_PARAMS[10]="--local"
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
  echo "[program:daemond]" >> $SUPERVISORD_CONF
  echo "command=$DAEMOND ${DAEMOND_RUN_PARAMS[*]}" >> $SUPERVISORD_CONF
  echo "directory=$DAEMOND_DATA" >> $SUPERVISORD_CONF
  echo "autostart=true" >> $SUPERVISORD_CONF
  echo "autorestart=true" >> $SUPERVISORD_CONF
  echo "stderr_logfile=$DAEMOND_DATA/console/niobiod.errors.log" >> $SUPERVISORD_CONF
  echo "stdout_logfile=$DAEMOND_DATA/console/niobiod.output.log" >> $SUPERVISORD_CONF
  echo "priority=100" >> $SUPERVISORD_CONF
fi

# start supervisord
if [ ! -z "$1" ]; then
  /usr/local/bin/supervisord --configuration $SUPERVISORD_CONF
  exec "$@"
else
  /usr/local/bin/supervisord --nodaemon --configuration $SUPERVISORD_CONF
fi
