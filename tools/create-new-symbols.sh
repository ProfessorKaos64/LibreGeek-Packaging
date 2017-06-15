#!/bin/bash

# About
# Processing all sonames in an extracted folder can follow a process such as what 
# Debian documentation describes. To use the below, move any .symbols install files 
# out of the debian/ directory, build the package, then move them back for the next step.
# It is advised to use a temporry directory containing the old symbols files and the build debs.

rm -rf newsymbols
mkdir -p  newsymbols

# find lib packages with symbols
version="5.6.0"
pkgs=$(find . -type f -name "*.symbols" -printf "%f\n" | sed "s|.symbols||g")

for pkg in ${pkgs};
do

	dpkg -x ${pkg}_*.deb ${pkg}_${version}
	: > newsymbols/${pkg}.symbols
	dpkg-gensymbols -v${version} -p${pkg} -P${pkg}_${version} -Onewsymbols/${pkg}.symbols
	rm -rf ${pkg}_${version}/

done
