#!/usr/bin/env bash

rm -rf tests
mkdir tests
testsdir=$PWD/tests

tmpdir=$(mktemp -d)
cd $tmpdir
git clone --recursive https://github.com/riscv-software-src/riscv-tests.git

cd riscv-tests
autoconf
./configure --prefix=$testsdir --with-xlen=32
echo "a:" > benchmarks/Makefile
make
make install

cd $testsdir
mv share/riscv-tests/isa/* .
rm -rf share

