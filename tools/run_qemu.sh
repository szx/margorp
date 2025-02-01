#!/usr/bin/env bash
set -e
pushd "$(dirname ${BASH_SOURCE:0})"
trap popd EXIT

. build.sh

. simulate_input.sh &

qemu-system-x86_64 -name "margorp" -monitor unix:/tmp/qemu-monitor-socket,server,nowait -no-reboot -no-shutdown -machine q35           \
    -drive if=none,id=usbstick,format=raw,file=../target/disk.bin   \
    -usb                                                            \
    -device nec-usb-xhci,id=xhci                                    \
    -device usb-storage,bus=xhci.0,drive=usbstick
    #-hda ../target/disk.bin
    # -S -gdb "tcp::1235" -d int,cpu_reset,in_asm,exec
    # -display curses
