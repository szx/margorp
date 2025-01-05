#!/usr/bin/env bash
set -e
pushd "$(dirname ${BASH_SOURCE:0})"
trap popd EXIT

sudo dd if=../target/disk.bin of=/dev/sdb status=progress bs=512
