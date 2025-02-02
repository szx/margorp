#!/usr/bin/env bash
set -e
pushd "$(dirname ${BASH_SOURCE:0})"
trap popd EXIT

sleep 1
cargo run --manifest-path ./qemu_automation/Cargo.toml
