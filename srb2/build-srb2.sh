#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-srb2.sh
# Script Ver:	1.0.8
# Description:	Attempts to builad a deb package from latest Sonic Robo Blast 2
#		github release
#
# See:		https://github.com/STJr/SRB2
# See:    https://github.com/STJr/SRB2/issues/45
#
# Usage:	./build-srb2.sh [opts]
# Opts:		[--build-data]
# Opts:		[--testing]
#		Modifys build script to denote this is a test package build.
# -------------------------------------------------------------------------------

#################################################
# Set variables
#################################################

arg1="$1"
scriptdir=$(pwd)
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

	REPO_FOLDER="/home/mikeyd/packaging/SteamOS-Tools/incoming_testing"
	
else

	REPO_FOLDER="/home/mikeyd/packaging/SteamOS-Tools/incoming"
	
fi

# upstream vars
# build from specific commit for stability
#git_url="https://github.com/STJr/SRB2"
git_url="https://github.com/ProfessorKaos64/SRB2"
rel_target="brewmaster"
commit="5c09c31"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS=""
export STEAMOS_TOOLS_BETA_HOOK="false"
pkgname="srb2"
pkgver="2.1.14"
upstream_rev="1"
pkgrev="1"
DIST="brewmaster"
urgency="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set build_dir
export build_dir="${HOME}/build-${pkgname}-temp"
src_dir="${pkgname}-${pkgver}"
git_dir="${build_dir}/${src_dir}"

install_prereqs()
{
	clear

	if [[ "$arg1"  == '--build-data' ]]; then
		echo -e "==INFO==\nBuilding both main data package and data pacakge\n"
	fi

	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s

	# install basic build packages
	sudo apt-get -y --force-yes install build-essential pkg-config bc debhelper \
	libpng12-dev libglu1-mesa-dev libgl1-mesa-dev nasm:i386 libsdl2-dev libsdl2-mixer-dev \
	libgme-dev

}

main()
{

	# create build_dir
	if [[ -d "${build_dir}" ]]; then

		sudo rm -rf "${build_dir}"
		mkdir -p "${build_dir}"

	else

		mkdir -p "${build_dir}"

	fi

	# enter build dir
	cd "${build_dir}" || exit

	# install prereqs for build
	
	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi


	# Clone upstream source code and branch

	echo -e "\n==> Obtaining upstream source code\n"

	# clone (use recursive to get the assets folder)
	git clone -b "$rel_target" "$git_url" "$git_dir"

	# get suffix from target commit (stable targets for now)
	cd "${git_dir}"
	#git checkout $commit 1> /dev/null
	commit=$(git log -n 1 --pretty=format:"%h")
	pkgsuffix="git${commit}+bsos${pkgrev}"

	# copy in modified files until fixed upstream
	# cp "$scriptdir/rules" "${git_dir}/debian"

	#################################################
	# Prepare package (main)
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# enter build dir to package attempt
	cd "${build_dir}"

	# create the tarball from latest tarball creation script
	# use latest revision designated at the top of this script

	# create source tarball
	tar -cvzf "${pkgname}_${pkgver}+${pkgsuffix}.orig.tar.gz" "${src_dir}"

	# enter source dir
	cd "${src_dir}"


	echo -e "\n==> Updating changelog"
	sleep 2s

 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${pkgver}+${pkgsuffix}" --package "${pkgname}" -D "${DIST}" -u "${urgency}"

	else

		dch -p --create --force-distribution -v "${pkgver}+${pkgsuffix}" --package "${pkgname}" -D "${DIST}" -u "${urgency}"

	fi


 	#################################################
	# Build Debian package (main)
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
	sleep 2s

	#  build
	DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

	#################################################
	# Prepare Debian package (data) - if needed
	#################################################

	if [[ "$arg1" == "--build-data" ]]; then

		# now we need to build the data package
		# Pkg ver is independent* of the version of srb2
		# See: https://github.com/STJr/SRB2/issues/45#issuecomment-180838131
		pkgver_data="2.1.14"
		pkgname_data="srb2-data"
		data_dir="assets"

		echo -e "\n==> Building Debian package ${pkgname_data} from source\n"
		sleep 2s

		# enter build dir to package attempt
		cd "${git_dir}"

		# create the tarball from latest tarball creation script
		# use latest revision designated at the top of this script

		# create source tarball
		tar -cvzf "${pkgname_data}_${pkgver_data}.orig.tar.gz" "${data_dir}"

		# enter source dir
		cd "${data_dir}"

		# Create basic changelog format

		cat <<-EOF> changelog.in
		$pkgname_data (${pkgver_data}) $DIST; urgency=low

		  * Packaged deb for SteamOS-Tools
		  * See: packages.libregeek.org
		  * Upstream authors and source: $git_url

		 -- $uploader  $date_long

		EOF

		# Perform a little trickery to update existing changelog or create
		# basic file
		cat 'changelog.in' | cat - debian/changelog > temp && mv temp debian/changelog

		# open debian/changelog and update
		echo -e "\n==> Opening changelog for confirmation/changes."
		sleep 3s
		nano "debian/changelog"

	echo -e "\n==> Updating changelog"
	sleep 2s

	 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${pkgver}+${pkgsuffix}" --package "${pkgname}" -D "${DIST}" -u "${urgency}"

	else

		dch -p --create --force-distribution -v "${pkgver}+${pkgsuffix}" --package "${pkgname}" -D "${DIST}" -u "${urgency}"

	fi


		#################################################
		# Build Debian package (data)
		#################################################

		echo -e "\n==> Building Debian package ${pkgname_data} from source\n"
		sleep 2s

		#  build
		DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

		# Move packages to build dir
		mv ${git_dir}/*${pkgver_data}* "${build_dir}"

	# end build data run
	fi

	#################################################
	# Cleanup
	#################################################

	# clean up dirs

	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)

	# output finish
	echo -e "\nTime started: ${time_stamp_start}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"


	# assign value to build folder for exit warning below
	build_folder=$(ls -l | grep "^d" | cut -d ' ' -f12)

	# back out of build temp to script dir if called from git clone
	if [[ "${scriptdir}" != "" ]]; then
		cd "${scriptdir}" || exit
	else
		cd "${HOME}" || exit
	fi

	# inform user of packages
	echo -e "\n############################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you don't, please check build dependcy errors listed above."
	echo -e "############################################################\n"

	echo -e "Showing contents of: ${build_dir}: \n"
	ls "${build_dir}" | grep -E "${pkgver}" "srb2"

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		# transfer files
		if [[ -d "${build_dir}" ]]; then
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${build_dir}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${build_dir}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main and log to tmp
main | tee "/tmp/${pkgname}-build-log-temp.txt"

# convert log file to Unix compatible ASCII
strings "/tmp/${pkgname}-build-log-temp.txt" > "/tmp/${pkgname}-build-log.txt"

# strings does catch all characters that I could 
# work with, final cleanup
sed -i 's|\[J||g' "/tmp/${pkgname}-build-log.txt"

# remove file not needed anymore
rm -f "/tmp/${pkgname}-build-log-temp.txt"