#!/bin/bash

set -e

trap 'kill $(jobs -p)' EXIT

SYSTEM_NAME=$(uname -s)

TCPTUNNEL_EXE="./tcp_tunnel_device_macos"
SIMPLE_MDNS_DEVICE_EXE="./simple_mdns_device_macos"

if [ "${SYSTEM_NAME}" == "Linux" ]; then
    TCPTUNNEL_EXE="./tcp_tunnel_device_linux"
    SIMPLE_MDNS_DEVICE_EXE="./simple_mdns_device_linux"
fi;

function run {
    local config=$1
    shift
    local opts=$*
    ${TCPTUNNEL_EXE} -H ./config/$config --random-ports $opts 2>&1 > /tmp/tunnel-$config
}

#find ./config -type d -name state -exec git checkout {} \; || true

run localPairLocalOpen &
run localPairLocalInitial &
run localPairPasswordOpen &
run localPasswordPairingDisabledConfig &
run localPasswordInvite &

${SIMPLE_MDNS_DEVICE_EXE} pr-mdns de-mdns swift-test-subtype swift-txt-key swift-txt-val

wait
