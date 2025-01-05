#!/usr/bin/env bash
set -e
pushd "$(dirname ${BASH_SOURCE:0})"
trap popd EXIT

rm -rf ../target
mkdir ../target

cd ../src

nasm -o ../target/bootsector.elf -f elf64 -F dwarf -g bootsector.asm
ld -Ttext=0x7c00 --oformat binary -o ../target/bootsector.bin ../target/bootsector.elf

nasm -o ../target/payload_16.elf -f elf64 -F dwarf -g payload_16.asm
ld -Ttext=0x500 --oformat binary -o ../target/payload_16.bin ../target/payload_16.elf

nasm -o ../target/payload_64.elf -f elf64 -F dwarf -g payload_64.asm
ld -Ttext=0x700 --oformat binary -o ../target/payload_64.bin ../target/payload_64.elf

cd ../tools

printf "\n\0" | cat ../src/forth.margorp - > ../target/forth.margorp

cat ../target/bootsector.bin ../target/payload_16.bin ../target/payload_64.bin ../target/forth.margorp > ../target/disk.bin
truncate -s1032192 ../target/disk.bin

