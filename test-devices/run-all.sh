#!/bin/bash

set -e

function run {
    local config=$1
    shift
    local opts=$*
    ./tcp_tunnel_device_macos -H ./config/$config --random-ports $opts 2>&1 > /tmp/tunnel-$config
}

run localPairLocalOpen &
run localPasswordPairingDisabledConfig &
run localPasswordProtectedDevice &

./simple_mdns_device_macos pr-mdns de-mdns swift-test-subtype swift-txt-key swift-txt-val

wait
