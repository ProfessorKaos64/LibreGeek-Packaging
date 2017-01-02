#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    		Michael DeGuzis
# Git:			https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	build-kodi.sh
# Script Ver:		1.5.7
# Description:		Attmpts to build a deb package from kodi-src
#               	https://github.com/xbmc/xbmc/blob/master/docs/README.linux
#               	This is a fork of the build-deb-from-src.sh script. Due to the
#               	amount of steps to build kodi, it was decided to have it's own
#               	script. A deb package is built from this script.
#
# Usage:      		./build-kodi.sh --cores [cpu cores]
#			./build-kodi.sh [--package-deb][--source]
# See Also:		https://github.com/xbmc/xbmc-packaging
# Opts:			[--testing]
#			Modifys build script to denote this is a test package build.
# -------------------------------------------------------------------------------

#################################################
# Set variables
#################################################

# source args
build_opts="$1"
cores_num="$2"

TIME_START=$(date +%s)
TIME_STAMP_START=(`date +"%T"`)

# remove old log
rm -f "kodi-build-log.txt"

# Specify a final arg for any extra options to build in later
# The command being echo'd will contain the last arg used.
# See: http://www.cyberciti.biz/faq/linux-unix-bsd-apple-osx-bash-get-last-argument/
export final_opts=$(echo "${@: -1}")

ARG1="$1"
SCRIPTDIR=$(pwd)
TIME_START=$(date +%s)
TIME_STAMP_START=(`date +"%T"`)

# Check if USER/HOST is setup under ~/.bashrc, set to default if blank
# This keeps the IP of the remote VPS out of the build script

if [[ "${REMOTE_USER}" == "" || "${REMOTE_HOST}" == "" ]]; then

	# fallback to local repo pool TARGET(s)
	REMOTE_USER="mikeyd"
	REMOTE_HOST="archboxmtd"
	REMOTE_PORT="22"

fi

if [[ "$final_opts" == "--testing" ]]; then

	REPO_FOLDER="/mnt/server_media_y/packaging/steamos-tools/incoming_testing"

else

	REPO_FOLDER="/mnt/server_media_y/packaging/steamos-tools/incoming"

fi

set_vars()
{

	###################################
	# package vars
	###################################

	PKGNAME="kodi"
	UPLOADER="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
	MAINTAINER="ProfessorKaos64"
	PKGREV="1"
	DIST="${DIST:=brewmaster}"
	URGENCY="low"
	BUILDER="pdebuild"
	BUILDOPTS="--debbuildopts \"-j4\""
	export USE_NETWORK="yes"
	export STEAMOS_TOOLS_BETA_HOOK="true"
	ARCH="amd64"
	DATE_LONG=$(date +"%a, %d %b %Y %H:%M:%S %z")
	DATE_SHORT=$(date +%Y%m%d)

	# source vars
	SRC_URL="git://github.com/xbmc/xbmc.git"
	export BUILD_TMP="$HOME/package-builds/build-${PKGNAME}-tmp"
	SRC_DIR="${BUILD_TMP}/kodi-source"

	# Set TARGET for xbmc sources
	# Do NOT set a tag default (leave blank), if you wish to use the tag chooser
	KODI_TAG=""

	###################
	# global vars
	###################

	# Allow more concurrent threads to be specified
	if [[ "$build_opts" == "--cores" ]]; then

		# set cores
		cores="$core_num"

	else

		# default to 2 cores as fallback
		cores="4"
	fi

	# Set script defaults for building packages or source directly
	if [[ "$extra_opts" == "--source" || "$ARG1" == "--source" ]]; then

		# set package to yes if deb generation is requested
		PACKAGE_DEB="no"

	elif [[ "$extra_opts" == "--skip-build" || "$ARG1" == "--skip-build" ]]; then

		# If Kodi is confirmed by user to be built already, allow build
		# to be skipped and packaging to be attmpted directly
		SKIP_BUILD="yes"
		PACKAGE_DEB="yes"

	else

		# Proceed with default actions
		PACKAGE_DEB="yes"

	fi

	##################################
	# Informational
	##################################

	# Source build notes:
	# https://github.com/xbmc/xbmc/blob/master/docs/README.linux

	# Current version:
	# https://github.com/xbmc/xbmc/blob/master/version.txt

	# model control file after:
	# https://packages.debian.org/sid/kodi

	# Current checkinstall config:
	# cfgs/source-builds/kodi-checkinstall.txt

}

kodi_clone()
{

	echo -e "\n==> Obtaining upstream source code"

	if [[ -d "${SRC_DIR}" ]]; then

		echo -e "\n==Info==\nGit source files already exist! Remove and [r]eclone or clean and [u]pdate? ?\n"
		sleep 1s
		read -ep "Choice: " git_choice

		if [[ "$git_choice" == "r" ]]; then

			echo -e "\n==> Removing and cloning repository again...\n"
			sleep 2s
			# reset retry flag
			retry="no"
			# clean and clone
			sudo rm -rf "${BUILD_TMP}" && mkdir -p "${BUILD_DIR}"
			git clone "${SRC_URL}" "${SRC_DIR}"

		else

			# Clean up and changes
			echo "Removing tmp files and other cruft from build dir and source dir"
			find "${BUILD_TMP}" -name '*.dsc' -o -name '*.deb' -o -name '*.build' \
			-exec rm -rf "{}" \;
			cd "${SRC_DIR}"
			# clean, reset on master, and pull new changes
			git clean -xfd
			git reset --hard master
			git pull

		fi

	else

			echo -e "\n==> Git directory does not exist. cloning now...\n"
			sleep 2s
			# reset retry flag
			retry="no"
			# create and clone to current dir
			mkdir -p "${BUILD_TMP}" || exit 1
			git clone "${SRC_URL}" "${SRC_DIR}"

	fi

}

function_install_pkgs()
{

	# cycle through packages defined

	for PKG in ${PKGS};
	do

		# assess via dpkg OR traditional 'which'
		PKG_OK_DPKG=$(dpkg-query -W --showformat='${Status}\n' $PKG | grep "install ok installed")
		#PKG_OK_WHICH=$(which $PKG)

		if [[ "$PKG_OK_DPKG" == "" ]]; then

			echo -e "\n==INFO==\nInstalling package: ${PKG}\n"
			sleep 1s

			if sudo apt-get install ${PKG} -y --force-yes; then

				echo -e "\n${PKG} installed successfully\n"
				sleep 1s

			else
				echo -e "Cannot install ${PKG}. Exiting in 15s. \n"
				sleep 15s
				exit 1
			fi

		elif [[ "$PKG_OK_DPKG" != "" ]]; then

			echo -e "Package ${PKG} [OK]"
			sleep 0.1s

		fi

	done

}

kodi_prereqs()
{

	# Main build dependencies are installed via desktop-software.sh
	# from the software list cfgs/software-lists/kodi-src.txt

	echo -e "\n==> Installing main deps for building\n"
	sleep 2s

	if [[ "${BUILDER}" != "pdebuild" && "${BUILDER}" != "sbuild" && "${PACKAGE_DEB}" == "yes" ]]; then

		# Javis control file lists 'libglew-dev libjasper-dev libmpeg2-4-dev', but they are not
		# in the linux readme

		PKGS="autoconf automake autopoint autotools-dev cmake curl dcadec-dev default-jre \
		gawk gperf libao-dev libasound2-dev libass-dev libavahi-client-dev libavahi-common-dev \
		libbluetooth-dev libbluray-dev libboost-dev libboost-thread-dev libbz2-dev libcap-dev \
		libcdio-dev libcec-dev libcurl4-openssl-dev libcwiid-dev libdbus-1-dev \
		libegl1-mesa-dev libfontconfig1-dev libfribidi-dev libgif-dev libgl1-mesa-dev \
		libiso9660-dev libjpeg-dev libltdl-dev liblzo2-dev libmicrohttpd-dev \
		libmodplug-dev libmpcdec-dev libmysqlclient-dev libnfs-dev libpcre3-dev \
		libplist-dev libpng12-dev libpulse-dev librtmp-dev libsdl2-dev libshairplay-dev \
		libsmbclient-dev libsqlite3-dev libssh-dev libssl-dev libswscale-dev libtag1-dev \
		libtinyxml-dev libtool libudev-dev libusb-dev libva-dev libvdpau-dev \
		libxinerama-dev libxml2-dev libxmu-dev libxrandr-dev libxslt1-dev libxt-dev libyajl-dev \
		lsb-release nasm:i386 python-dev python-imaging python-support swig unzip uuid-dev yasm \
		zip zlib1g-dev libcrossguid-dev libglew-dev libjasper-dev libmpeg2-4-dev"

		# install dependencies / packages
		function_install_pkgs

		#####################################
		# Dependencies - Debian sourced
		#####################################

		echo -e "\n==> Installing build deps for packaging\n"
		sleep 2s

		PKGS="build-essential fakeroot devscripts checkinstall cowbuilder pbuilder debootstrap \
		cvs fpc gdc libflac-dev libsamplerate0-dev libgnutls28-dev"

		# install dependencies / packages
		function_install_pkgs

		echo -e "\n==> Installing specific kodi build deps\n"
		sleep 2s

		# Origin: ppa:team-xbmc/ppa
		# Only install here if not using auto-build script (which installs them after)

		PKGS="libcec3 libcec-dev libafpclient-dev libgif-dev libmp3lame-dev libgif-dev libp8-platform-dev"

		# install dependencies / packages
		function_install_pkgs

		# Origin: ppa:team-xbmc/xbmc-nightly
		# It seems shairplay, libshairplay* are too old in the stable ppa
		PKGS="libshairport-dev libshairplay-dev shairplay"

		# install dependencies / packages
		function_install_pkgs

	elif [[ "${BUILDER}" == "pdebuild" &&  "${PACKAGE_DEB}" == "yes" ]]; then

		# Still need a few basic packages
		sudo apt-get install -y --force-yes curl

	else

		# If we are not packaging a deb, set to master TARGET build
        	TARGET="master"
        	PKGVER="${KODI_TAG}"

	fi
}

kodi_package_deb()
{

	# Debian link: 	    https://wiki.debian.org/BuildingTutorial
	# Ubuntu link: 	    https://wiki.ubuntu.com/PbuilderHowto
	# XBMC/Kodi readme: https://github.com/xbmc/xbmc/blob/master/tools/Linux/packaging/README.debian

	# Ensure we are in the proper directory
	cd "${SRC_DIR}"

	# show tags instead of TARGETes
	git tag -l --column

	echo -e "\nWhich Kodi release do you wish to build for:"
	echo -e "Type 'master' to use the master tree\n"

	# get user choice
	sleep 0.2s
	read -erp "Release Choice: " KODI_TAG

	# If the tag is left blank, set to master

	# checkout proper release from list
	if [[ "${KODI_TAG}" != "master" && "${KODI_TAG}" != "" ]]; then

		# Check out requested tag
		git checkout "tags/${KODI_TAG}"

	else

		# use master TARGET, set version tag to current latest tag
		KODI_TAG=$(git describe --abbrev=0 --tags)

	fi

	# set release for upstream xbmc packaging fork
	# Krypton does not have packaging upstream and the master tree does not work.
	# Therefore, work was done to package Krypton.
	# See: github.com/ProfessorKaos64/xbmc-packaging/
	if echo ${KODI_TAG} | grep -i "Gotham" 1> /dev/null; then KODI_RELEASE="Gotham"; fi
	if echo ${KODI_TAG} | grep -i "Isengard" 1> /dev/null; then KODI_RELEASE="Isengard"; fi
	if echo ${KODI_TAG} | grep -i "Jarvis" 1> /dev/null; then KODI_RELEASE="Jarvis"; fi
	if echo ${KODI_TAG} | grep -i "Krypton" 1> /dev/null; then KODI_RELEASE="Krypton"; fi

	# set release for changelog
        PKGVER="${KODI_RELEASE}+git+bsos${PKGREV}"

	############################################################
	# Add any overrides for setup below
	############################################################

	# change address in xbmc/tools/Linux/packaging/mk-debian-package.sh
	# See: http://unix.stackexchange.com/a/16274
	# This was done only at prior a point to satisfy some build deps. This has since
	# been corrected. 'mk-debian-package.sh' handles all package naming and will try
	# to sign as wnsipex. This is ok, since we will sign with reprepro.

	# However, this is still used to adjust the changelog structure
	# This may be dropped in the future

	# Use our fork for packaging to control the version name
	if [[ "${KODI_RELEASE}" != "" ]]; then

		sed -i "s|\bxbmc/xbmc-packaging/archive/master.tar.gz\b|ProfessorKaos64/xbmc-packaging/archive/${KODI_RELEASE}.tar.gz|g" "tools/Linux/packaging/mk-debian-package.sh"

	fi

	# Perform build with script tool
	if [[ "${BUILDER}" == "pbuilder" || "${BUILDER}" == "pdebuild" ]]; then

		# Assess where pbuilder base config is, for multi-box installations
		echo "Where is your pbuilder base folder?"
		sleep 0.3s
		read -erp "Location: " PBUILDER_BASE

		if [[ "${PBUILDER_BASE}" == "" ]]; then

			# set to default on most systems
			PBUILDER_BASE="/var/cache/pbuilder/"

		fi

		# Add any overrides for mk-debian-package.sh below
		# The default in the script is '"${BUILDER}"' which will attmpt to sign the pkg

		RELEASEV="${KODI_TAG}" \
		DISTS="${DIST}" \
		ARCHS="${ARCH}" \
		BUILDER="${BUILDER}" \
		PDEBUILD_OPTS="${BUILDOPTS}" \
		PBUILDER_BASE="${PBUILDER_BASE}" \
		tools/Linux/packaging/mk-debian-package.sh

	else

		RELEASEV="${KODI_TAG}" \
		BUILDER="${BUILDER}" \
		PDEBUILD_OPTS="${BUILDOPTS}" \
		tools/Linux/packaging/mk-debian-package.sh

	fi

}

kodi_build_src()
{

	#################################################
	# Build Kodi source
	#################################################

	echo -e "\n==> Building Kodi in ${SRC_DIR}\n"

	# enter build dir
	cd "${SRC_DIR}"

	# checkout TARGET release
	git checkout "${TARGET}"

  	# create the Kodi executable manually perform these steps:
	if ./bootstrap; then

		echo -e "\nBootstrap successful\n"

	else

		echo -e "\nBoostrap failed. Exiting in 10 seconds."
		sleep 10s
		exit 1

	fi

	# ./configure <option1> <option2> PREFIX=<system prefix>...
	# (See --help for available options). For now, use the default PREFIX
        # A full listing of supported options can be viewed by typing './configure --help'.
	# Default install path is:

	# FOR PACKAGING DEB ONLY (TESTING)
	# It may seem that per "http://forum.kodi.tv/showthread.php?tid=80754", we need to
	# export package config.

	# Configure with bluray support
	# Rmove --disable-airplay --disable-airtunes, not working right now

	if ./configure --prefix=/usr --enable-libbluray --enable-airport; then

		echo -e "\nConfigured successfuly\n"

	else

		echo -e "\nConfigure failed. Exiting in 10 seconds."
		sleep 10s
		exit 1

	fi

	# make the package
	# By adding -j<number> to the make command, you describe how many
     	# concurrent jobs will be used. So for quad-core the command is:

	# make -j4

	# Default core number is 2 if '--cores $n' argument is not specified
	if make -j${cores}; then

		echo -e "\nKodi built successfuly\n"

	else

		echo -e "\nBuild failed. Exiting in 10 seconds."
		sleep 10s
		exit 1

	fi

	# install source build if requested
	echo -e "\n==> Do you wish to install the built source code? [y/n]"

	# get user choice
	sleep 0.2s
	read -erp "Choice: " install_choice

	if [[ "${INSTALL_CHOICE}" == "y" ]]; then

		sudo make install

	elif [[ "${INSTALL_CHOICE}" == "n" ]]; then

		echo -e "\nInstallation skipped"

	else

		echo -e "\nInvalid response, skipping installation"

	fi

	# From v14 with commit 4090a5f a new API for binary addons is available. 
	# Not used for now ...

	# make -C tools/depends/TARGET/binary-addons

	####################################
	# (Optional) build Kodi test suite
	####################################

	#make check

	# compile the test suite without running it

	#make testsuite

	# The test suite program can be run manually as well.
	# The name of the test suite program is 'kodi-test' and will build in the Kodi source tree.
	# To bring up the 'help' notes for the program, type the following:

	#./kodi-test --gtest_help

	#################################################
	# Post install configuration
	#################################################

	echo -e "\n==> Adding desktop file and artwork"

	# copy files
	sudo cp "kodi.desktop" "/usr/share/applications"
	sudo cp "Kodi.png" "/home/steam/Pictures"

	# check if Kodi really installed
	if [[ -f "/usr/local/bin/kodi" ]]; then

		echo -e "\n==INFO==\nKodi was installed successfully."

	else

		echo -e "\n==INFO==\nKodi install unsucessfull\n"

	fi

}

show_build_summary()
{

	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$TIME_START) / 60 " | bc)

	cat <<-EOF
	----------------------------------------------------------------
	Summary
	----------------------------------------------------------------
	Time started: ${TIME_STAMP_START}
	Time end: ${time_stamp_end}
	Total Runtime (minutes): $runtime

	EOF
	sleep 2s

	# If "build_all" is requested, skip user interaction
	# Display output based on if we were source building or building
	# a Debian package

	if [[ "${PACKAGE_DEB}" == "no" ]]; then

		cat <<-EOF
		If you chose to build from source code, you should now be able
		to add Kodi as a non-Steam game in Big Picture Mode. Please
		see see the wiki for more information.

		EOF

	elif [[ "${PACKAGE_DEB}" == "yes" ]]; then

		cat <<-EOF
		###############################################################
		If package was built without errors you will see it below.
		If you don't, please check build dependcy errors listed above.
		###############################################################

		EOF

		echo -e "Showing contents of: ${BUILD_TMP}: \n"
		ls "${BUILD_TMP}"

		echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
		sleep 0.5s
		# capture command
		read -ep "Choice: " TRANSFER_CHOICE

		if [[ "${TRANSFER_CHOICE}" == "y" ]]; then

			# transfer files
			if [[ -d "${BUILD_TMP}" ]]; then
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_TMP}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}


			fi

		elif [[ "${TRANSFER_CHOICE}" == "n" ]]; then
			echo -e "Upload not requested\n"
		fi

	fi

}


####################################################
# Script sequence
####################################################
# Main order of operations
main()
{

	# Process main functions
	set_vars
	kodi_prereqs
	kodi_clone

	# Process how we are building
	if [[ "${PACKAGE_DEB}" == "yes" ]]; then

		kodi_package_deb

	elif [[ "${PACKAGE_DEB}" == "no" ]]; then

		kodi_build_src

	else

		echo -e "Invalid package options detected. Exiting"
		sleep 2s && exit 1

	fi

	# go to summary
	show_build_summary

}

#####################################################
# MAIN
#####################################################
main | tee log_tmp.txt

#####################################################
# cleanup
#####################################################

# convert log file to Unix compatible ASCII
strings log_tmp.txt > kodi-build-log.txt &> /dev/null

# strings does catch all characters that I could
# work with, final cleanup
sed -i 's|\[J||g' kodi-build-log.txt

# remove file not needed anymore
rm -f "log_tmp.txt"
