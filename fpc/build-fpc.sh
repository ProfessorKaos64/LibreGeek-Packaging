#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-fpc.sh
# Script Ver:	1.0.0
# Description:	Attempts to build a deb package from latest fpc
#		github release
#
# See:		https://github.com/graemeg/freepascal
#
# Usage:	build-fpc.sh
# Opts:		[--testing]
#		Modifys build script to denote this is a test package build.
# -------------------------------------------------------------------------------

#################################################
# Set variables
#################################################

arg1="$1"
SCRIPTDIR=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)


# Check if USER/HOST is setup under ~/.bashrc, set to default if blank
# This keeps the IP of the remote VPS out of the build script

if [[ "${REMOTE_USER}" == "" || "${REMOTE_HOST}" == "" ]]; then

	# fallback to local repo pool target(s)
	REMOTE_USER="mikeyd"
	REMOTE_HOST="archboxmtd"
	REMOTE_PORT="22"

fi

if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/mnt/server_media_y/packaging/ubuntu/incoming_testing"

else

	REPO_FOLDER="/mnt/server_media_y/packaging/ubuntu/incoming"

fi

# upstream vars
SRC_URL="https://github.com/graemeg/freepascal"
TARGET="master"

# package vars
DATE_LONG=$(date +"%a, %d %b %Y %H:%M:%S %z")
DATE_SHORT=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -nc"
export STEAMOS_TOOLS_BETA_HOOK="false"
PKGNAME="fpc"
PKGREV="1"
DIST="${DIST:-yakkety}"
PPA_REV=${PPA_REV:-""}
URGENCY="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set build directories
unset BUILD_TMP
export BUILD_TMP="${BUILD_TMP:=${HOME}/package-builds/build-${PKGNAME}-tmp}"
SRC_DIR="${BUILD_TMP}/${PKGNAME}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes build-essential binutils fp-compiler fp-units-base \
	fp-units-fcl fp-utils ghostscript libncurses-dev awk po-debconf txt2man

}

main()
{

	# create BUILD_TMP
	if [[ -d "${BUILD_TMP}" ]]; then

		sudo rm -rf "${BUILD_TMP}"
		mkdir -p "${BUILD_TMP}"

	else

		mkdir -p "${BUILD_TMP}"

	fi

	# enter build dir
	cd "${BUILD_TMP}" || exit

	# install prereqs for build

	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi

	# Set PKGSUFFIX based on Ubuntu DIST
	case "${DIST}" in

                trusty)
                PKGSUFFIX="trusty${PPA_REV}"
                ;;

		xenial)
		PKGSUFFIX="xenial${PPA_REV}"
		;;

		yakkety)
		PKGSUFFIX="yakkety${PPA_REV}"
		;;

	esac

	# Clone upstream source code and TARGET

	echo -e "\n==> Obtaining upstream source code\n"

	# clone
	git clone -b "${TARGET}" "${SRC_URL}" "${SRC_DIR}"
	cd "${SRC_DIR}"

	# Grab the real version from the version.pas file
        VER_MAJOR=$(cat compiler/version.pas | grep "version_nr =" | cut -d'=' -f 2 | sed 's/ //g;s/\x27//g;s/\;//')
	VER_MINOR=$(cat compiler/version.pas | grep "release_nr =" | cut -d'=' -f 2 | sed 's/ //g;s/\x27//g;s/\;//')
	VER_PATCH=$(cat compiler/version.pas | grep "patch_nr   =" | cut -d'=' -f 2 | sed 's/ //g;s/\x27//g;s/\;//')
	PKGVER="${VER_MAJOR}.${VER_MINOR}.${VER_PATCH}"

	# rename cloned folder to match
	cd ..
	mv $(basename "${SRC_DIR}") "${PKGNAME}-${PKGVER}"
	SRC_DIR="${BUILD_TMP}/${PKGNAME}-${PKGVER}"

	#################################################
	# Build package
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# create source tarball
	cd "${BUILD_TMP}"
	tar -cvzf "${PKGNAME}_${PKGVER}~${PKGSUFFIX}.orig.tar.gz" $(basename ${SRC_DIR})

	# Add debian files
	cp -r "${SCRIPTDIR}/debian" "${SRC_DIR}"

	# enter source dir
	cd "${SRC_DIR}"

	echo -e "\n==> Updating changelog"
	sleep 2s

	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-bad-version --force-distribution -v "${PKGVER}~${PKGSUFFIX}-${PKGREV}" \
		--package "${PKGNAME}" -D "${DIST}" -u "${URGENCY}" "Update to new 2.22 release"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${PKGVER}~${PKGSUFFIX}-${PKGREV}" \
		--package "${PKGNAME}" -D "${DIST}" -u "${URGENCY}" "Update release"
		nano "debian/changelog"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${PKGNAME} from source\n"
	sleep 2s

	#  build
	DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

	#################################################
	# Cleanup
	#################################################

	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)

	# output finish
	echo -e "\nTime started: ${time_stamp_start}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"

	# inform user of packages
	cat<<-EOF

	###############################################################
	If package was built without errors you will see it below.
	If you don't, please check build dependcy errors listed above.
	###############################################################

	Showing contents of: ${BUILD_TMP}

	EOF

	ls "${BUILD_TMP}" | grep -E "${PKGVER}"

	echo -e "\n==> Would you like to upload any packages that were built to the PPA? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		# Sign with debsign on repo host pc, not remotely
		# copy files to remote server
		rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" \
		--filter="merge ${HOME}/.config/libregeek-packaging/repo-filter.txt" \
		${BUILD_TMP}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

		# copy local repo changelog
		cp "${SRC_DIR}/debian/changelog" "${SCRIPTDIR}/debian"


	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main