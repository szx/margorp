#!/usr/bin/env bash
set -e
pushd "$(dirname ${BASH_SOURCE:0})"
trap popd EXIT

sleep 3
cat "../src/forth.margorp" | tr \\n \\r | sponge "../target/forth.margorp"
WINDOW_ID=$(xdotool search --name "QEMU \(margorp\)")
printf '\n' | cat ../target/forth.margorp - | xclip -i -selection clipboard
#xdotool windowactivate --sync "$WINDOW_ID" key --clearmodifiers "ctrl+v"
# HIRO run rust
#echo 'sendkey dot' | nc localhost 9137 -q0
#echo 'sendkey spc' | nc localhost 9137 -q0