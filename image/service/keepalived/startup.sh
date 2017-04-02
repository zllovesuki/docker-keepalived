#!/bin/bash -e

# set -x (bash debug) if log level is trace
# https://github.com/osixia/docker-light-baseimage/blob/stable/image/tool/log-helper
log-helper level eq trace && set -x

FIRST_START_DONE="${CONTAINER_STATE_DIR}/docker-keepalived-first-start-done"
# container first start
if [ ! -e "$FIRST_START_DONE" ]; then

  #
  # bootstrap config
  #
  sed -i --follow-symlinks "s|{{ KEEPALIVED_INTERFACE }}|$KEEPALIVED_INTERFACE|g" ${CONTAINER_SERVICE_DIR}/keepalived/assets/keepalived.conf
  sed -i --follow-symlinks "s|{{ KEEPALIVED_PRIORITY }}|$KEEPALIVED_PRIORITY|g" ${CONTAINER_SERVICE_DIR}/keepalived/assets/keepalived.conf
  sed -i --follow-symlinks "s|{{ KEEPALIVED_PASSWORD }}|$KEEPALIVED_PASSWORD|g" ${CONTAINER_SERVICE_DIR}/keepalived/assets/keepalived.conf

  if [ -n "$KEEPALIVED_NOTIFY" ]; then
    sed -i --follow-symlinks "s|{{ KEEPALIVED_NOTIFY }}|notify \"$KEEPALIVED_NOTIFY\"|g" ${CONTAINER_SERVICE_DIR}/keepalived/assets/keepalived.conf
    chmod +x $KEEPALIVED_NOTIFY
  else
    sed -i --follow-symlinks "/{{ KEEPALIVED_NOTIFY }}/d" ${CONTAINER_SERVICE_DIR}/keepalived/assets/keepalived.conf
  fi

  # unicast peers
  for peer in $(complex-bash-env iterate KEEPALIVED_UNICAST_PEERS)
  do
    sed -i --follow-symlinks "s|{{ KEEPALIVED_UNICAST_PEERS }}|${!peer}\n    {{ KEEPALIVED_UNICAST_PEERS }}|g" ${CONTAINER_SERVICE_DIR}/keepalived/assets/keepalived.conf
  done
  sed -i --follow-symlinks "/{{ KEEPALIVED_UNICAST_PEERS }}/d" ${CONTAINER_SERVICE_DIR}/keepalived/assets/keepalived.conf

  # virtual ips
  for vip in $(complex-bash-env iterate KEEPALIVED_VIRTUAL_IPS)
  do
    sed -i --follow-symlinks "s|{{ KEEPALIVED_VIRTUAL_IPS }}|${!vip}\n    {{ KEEPALIVED_VIRTUAL_IPS }}|g" ${CONTAINER_SERVICE_DIR}/keepalived/assets/keepalived.conf
  done
  sed -i --follow-symlinks "/{{ KEEPALIVED_VIRTUAL_IPS }}/d" ${CONTAINER_SERVICE_DIR}/keepalived/assets/keepalived.conf

  touch $FIRST_START_DONE
fi

# try to delete virtual ips from interface
for vip in $(complex-bash-env iterate KEEPALIVED_VIRTUAL_IPS)
do
  ip addr del ${!vip}/32 dev ${KEEPALIVED_INTERFACE} || true
done

if [ ! -e "/etc/keepalived/keepalived.conf" ]; then
  ln -sf ${CONTAINER_SERVICE_DIR}/keepalived/assets/keepalived.conf /etc/keepalived/keepalived.conf
fi

exit 0
