#========================================================================
# Build Script for steamos-xpad-dkms
#========================================================================
#
# Author:       Michael DeGuzis,
# Date:         20150929
# Version:      0.3
# Description:  steamos-xpad-dkms build script for packaging.
#               This build script is meant for PPA uploads.
#
# Opts:		[--testing]
#		Modifys build script to denote this is a test package build.
#=======================================================================

#################################################
# Set variables
#################################################

arg1="$1"
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



if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/mnt/server_media_y/packaging/steamos-tools/incoming_testing"
	
else

	REPO_FOLDER="/mnt/server_media_y/packaging/steamos-tools/incoming"
	
fi

# Upstream vars from Valve's repo
steamos_kernel_url='https://github.com/ValveSoftware/steamos_kernel'
xpadsteamoscommit='9ce95a199ff868f76b059338ee8d5760aa33a064'
xpadsteamoscommit_short='9ce95a1'
xpad_source_file="https://github.com/ValveSoftware/steamos_kernel/raw/9ce95a199ff868f76b059338ee8d5760aa33a064/drivers/input/joystick/xpad.c"

# define base version
PKGNAME="steamos-xpad-dkms"
PKGVER="20151001+git2"
PKGREV="1"
pkgrel="wily"

# BUILD_TMPs
export BUILD_TMP="${HOME}/pkg-build-dir"
pkg_folder="${PKGNAME}-${PKGVER}-${PKGREV}~${pkgrel}"

# Define TARGET
BRANCH="master"

# Define upload TARGET
LAUNCHPAD_PPA="ppa:mdeguzis/steamos-tools"

# Define UPLOADER for changelog
UPLOADER="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"

# Define package MAINTAINER for dsc and $PKGNAME-$PKGVER-$pkgrel file 
pkgMAINTAINER="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"

clear

cat<<- EOF
#####################################################################
Building ${PKGNAME}-${PKGVER}-${PKGREV}~${pkgrel}
#####################################################################

EOF

if [[ -n "$1" ]]; then

  echo "
  echo -e "==INFO==\nbuild TARGET is $1"
  echo "

else
  echo -e "==INFO==\nbuild TARGET is source"
  echo "
fi

sleep 2s

cat<<- EOF
##########################################
Fetching necessary packages for build
##########################################

EOF

# install needed packages
sudo apt-get install -y --force-yes git devscripts build-essential checkinstall \
debian-keyring debian-archive-keyring cmake g++ g++-multilib \
libqt4-dev libqt4-dev libxi-dev libxtst-dev libX11-dev bc libsdl2-dev \
gcc gcc-multilib vim dh-make gnupg-agent pinentry-curses

cat <<-EOF
##########################################
Setup build directory
##########################################

EOF

echo -e "\n==> Setup $BUILD_TMP\n"

# setup build directory
if [[ -d "${BUILD_TMP}" ]]; then

  # reset dir
  rm -rf "${BUILD_TMP}"
  mkdir -p "${BUILD_TMP}"
  cd "${BUILD_TMP}"

else

  # setup build dir
  mkdir -p "${BUILD_TMP}"
  cd "${BUILD_TMP}"

fi

cat <<-EOF
##########################################
Setup package base files
##########################################

EOF

echo -e "\n==> original tarball\n"
git clone https://github.com/mdeguzis/steamos-xpad-dkms

# sanity check
file steamos-xpad-dkms/

if [ $? -eq 0 ]; then
    echo "successfully cloned/copied"
else
    echo "git clone/copy failed, aborting"
    exit
fi

# Change git folder to match pkg version format
mv steamos-xpad-dkms "$pkg_folder"

# change to source folder
cd "$pkg_folder" || exit
git pull
git checkout $BRANCH
# remove git files
rm -rf .git .gitignore .hgeol .hgignore

# Create archive
echo -e "\n==> Creating archive\n"
cd .. || exit
tar cfj steamos-xpad-dkms.orig.tar.bz2 "$pkg_folder"
# The original tarball should not have the revision and release tacked on
mv "steamos-xpad-dkms.orig.tar.bz2" "${PKGNAME}-${PKGVER}.orig.tar.bz2"

cat <<-EOF
##########################################
Unpacking debian files
##########################################

EOF

# enter new package folder to work with Debian files
cd "$pkg_folder"

# (NOTICE: updated xpad.c when necessary)
# copy xpad.c over top the existing file on Github for updating
# Store this in the upstream git, rather than download here, or dpkg-source will complain 

echo -e "\n==> changelog"
# Change version, UPLOADER, insert change log comments
sed -i "s|version_placeholder|$PKGNAME_$PKGVER-$PKGREV~$pkgrel|g" debian/changelog
sed -i "s|UPLOADER|$uploader|g" debian/changelog
sed -i "s|DIST|$pkgrel|g" debian/changelog

echo -e "\nOpening change log for details to be added...\n"
sleep 3s
vim "debian/changelog"

echo -e "\n==> control"
sed -i "s|pkgMAINTAINER|$pkgmaintainer|g" debian/control

echo -e "\n==> rules\n"
sed -i "s|PKGVER|$PKGVER|g" debian/rules
sed -i "s|pkgrel|$pkgrel|g" debian/rules

if [[ -n "$1" ]]; then
  arg0=$1
else
  # set up default
  arg0=source
fi

case "$arg0" in
  compile)

cat <<-EOF

echo ##########################################
echo Building binary package now
echo ##########################################

EOF

    #build binary package
    "${BUILDER}" -us -uc

    if [ $? -eq 0 ]; then

cat <<-EOF
##########################################
Building finished
##########################################

EOF

        ls  "$pkg_folder"
         exit 0
    else
        echo "${BUILDER}" failed to generate the binary package, aborting"
        exit 1
    fi 
    ;;
  source)
    #get secret key
    gpgkey=$(gpg --list-secret-keys|grep "sec   "|cut -f 2 -d '/'|cut -f 1 -d ' ')

    if [[ -n "$gpgkey" ]]; then

cat <<-EOF
##########################################
Building source package
##########################################

EOF

      sleep 3s
      "${BUILDER}" -S -sa -k${gpgkey}

      if [ $? -eq 0 ]; then
        echo "
        ls -lah "${BUILD_TMP}"
        echo "
        echo "all good"
        echo "

        while true; do
            read -rp "Do you wish to upload the source package?    " yn
            case $yn in
                [Yy]* ) dput ppa:mdeguzis/steamos-tools ${BUILD_TMP}/${PKGNAME}-${PKGVER}-${PKGREV}~${pkgrel}_source.changes; break;;
                [Nn]* ) break;;
                * ) echo "Please answer yes or no.";;
            esac
        done

        exit 0
      else
        echo "${BUILDER}" failed to generate the source package, aborting"
        exit 1
      fi
    else
      echo "secret key not found, aborting"
      exit 1
    fi
    ;;
esac




