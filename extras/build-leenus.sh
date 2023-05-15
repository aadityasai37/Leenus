#!/bin/sh
#aditya
#########################################################################
#
# Builds Leenus distribution
#
# Usage: this script creates Leenus builds
#
# *** NOTE ***
# This script is not fully functional yet, several options like digital
# signing, RPM/DEB package creation are missing.
#
#########################################################################
#
# Options:

    echo "[*] Activity [V] Successful [X] Error [=] Result"
    echo ""

    # Umask used when creating files/directories
    OPTION_UMASK="027"

    # Directory name used to create package related directories (like /usr/local/include/leenus)
    OPTION_PACKAGE_DIRNAME="leenus"

    # Binary to test
    OPTION_BINARY_FILE="../leenus"

    # Check number of parameters
    if [ $# -eq 0 ]; then
        echo "[X] This build tool needs at least a version number (--version). Use --help for all parameters."
        exit 1
    fi

    # Check parameters
    case $1 in
        --help)
            echo "Define version:"
            echo "--version 1.2.3"
            exit 1
        ;;
        --version)
            shift
            LEENUS_VERSION=$1
        ;;
        *)
            echo "[X] Incorrect parameter"
            exit 1
        ;;
    esac

#
#########################################################################
#
# Functions:

    # Clean temporary files up
    CleanUp() {
        if [ ! "${TMPDIR}" = "" -a -d "${TMPDIR}" ]; then
            rm -rf ${TMPDIR}
        fi
    }

    Exit() {
        CleanUp
        exit 0
    }
    ExitFatal() {
        CleanUp
        exit 1
    }
#
#########################################################################
#

    # Clean files up if we get interrupted
    trap CleanUp INT

#
#########################################################################
#
    MYUSER=$(whoami)
    if [ "${MYUSER}" = "" ]; then
        echo "[X] Could not determine user"
    fi
    if [ "${MYUSER}" = "root" ]; then
        echo "[X] This script should not be executed as root"
    fi


    MYWORKDIR=$(pwd | awk -F / '{ for (i=1;i<=NF-2;i++){ printf $i"/" }; printf "\n"}' | sed 's./$..')
    if [ ! -d ${MYWORKDIR} ]; then
        echo "[X] Could not determine workdir (result: ${MYWORKDIR} seems invalid)"
        ExitFatal
    else
        echo "[=] workdir: ${MYWORKDIR}"
    fi


    MYBUILDDIR="/home/${MYUSER}/leenus-build"
    if [ ! -d ${MYBUILDDIR} ]; then
        echo "[X] ${MYBUILDDIR} not found"
        echo "    Hint: create it with mkdir ${MYBUILDDIR}"
        ExitFatal
    else
        echo "[=] builddir: ${MYBUILDDIR}"
    fi

    NEEDED_DIRS="debbuild rpmbuild rpmbuild/BUILD rpmbuild/BUILDROOT rpmbuild/RPMS rpmbuild/SOURCES rpmbuild/SRPMS"
    for I in ${NEEDED_DIRS}; do
        if [ ! -d "${MYBUILDDIR}/${I}" ]; then
            echo "[X] Missing directory: ${MYBUILDDIR}/${I}"
            echo "   Hint: create subdirs with cd ${MYBUILDDIR} && mkdir -p ${NEEDED_DIRS}"
            ExitFatal
        fi
    done

    DEBWORKDIR="${MYBUILDDIR}/debbuild"
    RPMWORKDIR="${MYBUILDDIR}/rpmbuild"
    echo "[=] RPM workdir: ${RPMWORKDIR}"
    #echo "Use: cd ${MYBUILDDIR} && mkdir rpm"


    # Check binaries

    GITBUILDPACKAGEBINARY=$(which git-buildpackage)
    if [ ! "${GITBUILDPACKAGEBINARY}" = "" ]; then
        echo "[=] git-buildpackage = ${GITBUILDPACKAGEBINARY}"
    else
        echo "[X] Can not find git-buildpackage binary"
        echo "    Hint: install git-buildpackage"
        ExitFatal
    fi

    RPMBUILDBINARY=$(which rpmbuild)
    if [ ! "${RPMBUILDBINARY}" = "" ]; then
        echo "[=] rpmbuild = ${RPMBUILDBINARY}"
    else
        echo "[X] Can not find rpmbuild binary"
        echo "    Hint: install rpmbuild"
        ExitFatal
    fi


    # Set umask
    umask ${OPTION_UMASK}
    if [ $? -eq 0 ]; then
        echo "[V] Setting umask to ${OPTION_UMASK}"
    else
        echo "[X] Could not set umask"
        ExitFatal
    fi

    # Check if we are in dev directory
    if [ -f ../leenus -a -f ./build-leenus.sh ]; then
        echo "[V] Active in proper directory"
    else
        echo "[X] This script should be executed from dev directory itself"
        ExitFatal
    fi




#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    # Create temporary build directory
    TMPDIR=$(mktemp -d /tmp/leenus-BUILDROOT.XXXXXX)
    if [ $? -eq 0 ]; then
        echo "[V] Creating temporary build directory"
        #echo "    BUILDROOT: ${TMPDIR}"
    else
        echo "[X] Could not create temporary build directory"
        ExitFatal
    fi

#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    echo "[*] Starting with building tarball"

    TARBALL="${MYBUILDDIR}/leenus_${LEENUS_VERSION}.orig.tar.gz"
    #if [ -f ${TARBALL} ]; then
    #     echo "[X] Tarball already exists "
    #     echo "    Hint: remove ${TARBALL}"
    #     ExitFatal
    #fi

    # Create tarball

    if [ -f ${TARBALL} ]; then
        echo "Tarball already exists for this version, not overwriting it"
    else
        tar -C ${MYWORKDIR} --exclude=debian --exclude=README.md --exclude=.bzr* --exclude=.git* -c -z -f ${TARBALL} leenus 2> /dev/null
        if [ -f ${TARBALL} ]; then
            echo "[V] Tarball created"
        else
            echo "[X] Tarball ${TARBALL} could not be created"
            ExitFatal
        fi
    fi

    TARBALL_MD5=$(md5sum ${TARBALL})
    TARBALL_SHA1=$(sha1sum ${TARBALL})

    echo "[*] Starting with RPM building process"

    # RPM creation
    SOURCEFILE_RPM="${RPMWORKDIR}/SOURCES/leenus-${LEENUS_VERSION}.tar.gz"
    if [ -f ${SOURCEFILE_RPM} ]; then
        if [ -f leenus.spec ]; then
            # adjust version in spec file
            VERSION_IN_SPECFILE=$(awk '/^Version:/ { print $2 }' leenus.spec)
            echo "[=] Found version ${VERSION_IN_SPECFILE}"
            if [ ${VERSION_IN_SPECFILE} = "" -o ! "${VERSION_IN_SPECFILE}" = "${LEENUS_VERSION}" ]; then
                echo "[X] Version in specfile is outdated"
                ExitFatal
            fi
            echo "[*] Start RPM building"
            #${RPMBUILDBINARY} --quiet -ba -bl leenus.spec 2> /dev/null
        else
            echo "[X] leenus.spec not found"
            ExitFatal
        fi

        RPMFILE="${RPMWORKDIR}/RPMS/noarch/leenus-${LEENUS_VERSION}-1.noarch.rpm"
        if [ -f ${RPMFILE} ]; then
            echo "[V] Building RPM successful!"
        else
            echo "[X] Could not find RPM file, most likely failed"
            echo "    Expected: ${RPMFILE}"
            ExitFatal
        fi
    else
        echo "[X] Could not find source file (${SOURCEFILE_RPM})"
        echo "    Hint: cp <leenus.tar.gz> ${SOURCEFILE_RPM}"
        #ExitFatal
    fi

    echo "[*] Starting with DEB building process"

        DEBCHANGELOGFULLVERSION=$(head -1 ../debian/changelog | awk '{ print $2 }' | sed 's/(//' | sed 's/)//')
        DEBCHANGELOGVERSION=$(echo ${DEBCHANGELOGFULLVERSION} | awk -F- '{ print $1 }')
        DEBCHANGELOGVERSIONREV=$(echo ${DEBCHANGELOGFULLVERSION} | awk -F- '{ print $2 }')
        if [ "${LEENUS_VERSION}" = "${DEBCHANGELOGVERSION}" ]; then
            echo "[V] Debian/changelog up-to-date"
        else
            echo "[X] Debian/changelog outdated"
            ExitFatal
        fi

#    BZRSTATUS=$(${BZRBINARY} status . 2>&1 > /dev/null; echo $?)
#    if [ "${BZRSTATUS}" = "0" ]; then
#        echo "[V] bzr has proper directory tree"
#        DEBCHANGELOGFULLVERSION=$(head -1 debian/changelog | awk '{ print $2 }' | sed 's/(//' | sed 's/)//')
#        DEBCHANGELOGVERSION=$(echo ${DEBCHANGELOGFULLVERSION} | awk -F- '{ print $1 }')
#        DEBCHANGELOGVERSIONREV=$(echo ${DEBCHANGELOGFULLVERSION} | awk -F- '{ print $2 }')
#        echo "[=] Version in Debian changelog: ${DEBCHANGELOGVERSION} (revision: ${DEBCHANGELOGVERSIONREV})"
#        if [ "${LEENUS_VERSION}" = "${DEBCHANGELOGVERSION}" ]; then
#            echo "[V] Debian/changelog up-to-date"
#        else
#            echo "[X] Debian/changelog outdated"
##            ExitFatal
#        fi
#        # execute command
#        # bzr builddeb . --build-dir ${DEBWORKDIR}/build-area/ --result-dir ${DEBWORKDIR}
#    elif [ "${BZRSTATUS}" = "3" ]; then
#        echo "[X] Tree is not initialized for BZR"
#        echo "    Hint: run bzr init while being in leenus directory (or bzr init ..)"
#        ExitFatal
#    else
#        echo "[X] Unknown error"
#        echo "Output: ${BZRSTATUS}"
#    fi

    if [ ! -d ${MYBUILDDIR}/git ]; then
        mkdir ${MYBUILDDIR}/git
    fi

    if [ -d ${MYBUILDDIR}/git/Leenus ]; then
        echo "git clone already exists"
        rm -rf ${MYBUILDDIR}/git/Leenus
        #git checkout tags/${LEENUS_VERSION}
    fi

    git clone https://github.com/CISOfy/Leenus.git ${MYBUILDDIR}/git/Leenus

    if [ -d ${MYBUILDDIR}/git/Leenus/debian/ ]; then
        echo "Copying build files into new tree"
        cp -R ../debian/* ${MYBUILDDIR}/git/Leenus/debian/
        cd ${MYBUILDDIR}/git/Leenus/debian/
        git add .
        git commit -m "Building process for Leenus release version ${LEENUS_VERSION}"
    else
        echo "[X] Could not copy debian directory and commit changes"
    fi
    #git tag -l ${MYBUILDDIR}/git/Leenus

    cd ..
    echo "Executing: ${GITBUILDPACKAGEBINARY} --git-tarball-dir=${MYBUILDDIR} --git-export-dir=${DEBWORKDIR} --git-ignore-new"
    ${GITBUILDPACKAGEBINARY} -S --git-tarball-dir=${MYBUILDDIR} --git-export-dir=${DEBWORKDIR} --git-ignore-new
    cd ${MYWORKDIR}

    echo "[V] Done"
    echo ""
    echo "---------------------------------------------"
    echo "RPM file:              ${RPMFILE}"
    echo "DEB file:              ${DEBWORKDIR}/leenus_${LEENUS_VERSION}_amd64.deb"
    echo "Tarball:               ${TARBALL}"
    echo "Tarball (SHA1):        ${TARBALL_SHA1}"
    echo ""
    echo "Actions:"
    echo " - Upload Debian package with dput (-f) my-ppa <source.changes>"



#=====================================================================

# Stop the script at this stage, rest is under development
Exit

#=====================================================================













#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    # Test script for errors
    echo -n "- Test Leenus script                                    "

    # Is file there?
    if [ ! -f ${OPTION_BINARY_FILE} ]; then echo "BAD (can't find ${OPTION_BINARY_FILE})"; exit 1; fi

    # Check script
    FIND=$(sh -n ${OPTION_BINARY_FILE} ; echo $?)
    if [ $FIND -eq 0 ]; then
        echo "OK"
    else
        echo "BAD"
    fi

#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    # Create SHA1 hashes
    echo -n "- Create SHA1 hashes                                   "
    SHA1HASH_LEENUS=$(grep -v '^#' ${OPTION_BINARY_FILE} | sha1)
    echo "DONE"
    echo "    Leenus (SHA1): ${SHA1HASH_LEENUS}"

    # Add hashes to script
    echo -n "- Injecting SHA1 hash into Leenus script                "
    echo "-NOT DONE-"

#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    echo -n "- Cleaning up OpenBSD package build... "
    if [ -f openbsd/+CONTENTS ]; then rm openbsd/+CONTENTS; fi
    echo "DONE"
    OPENBSD_CONTENTS="openbsd/+CONTENTS"

#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    echo -n "- Creating MD5 hashes..."
    PACKAGE_LIST_FILES=$(grep "^file:" files.dat | cut -d ':' -f3)

    for I in ${PACKAGE_LIST_FILES}; do

      echo -n "${I} "
      #FULLNAME=$(grep ":file:include:" files.dat)
      #echo "${FULLNAME}" >> ${OPENBSD_CONTENTS}
      echo "${I}" >> ${OPENBSD_CONTENTS}
      FILE="../${I}"
      MD5HASH=$(md5 -q ${FILE})
      echo "@md5 ${MD5HASH}" >> ${OPENBSD_CONTENTS}
      echo "@size 0000" >> ${OPENBSD_CONTENTS}
    done
    echo ""




#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    echo -n "- Cleaning up... "

    # Exit cleanly
    Exit

    echo "DONE"

#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# The End!

