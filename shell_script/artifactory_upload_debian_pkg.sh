#!/bin/bash

# Author: Rodrigo Pompei
# Version: 0.0.1
#
# Description
#    - This script will perform the upload of Debian packages to NS1 Artifactory
#
#     Examples:
#          ./artifactory_upload_debian_pkg.sh -s <source debian pkg location> -d <artifactory destination location>

usage () {
    cat <<HELP_USAGE

$0 <-s | --source_debian_pkg> <-d | --dest_artifactory> [--yes] [-h | --help]
    <-s  | --source_debian_pkg> source debian pkg location          Example: $0 -l libcap2-bin.deb or http://ftp.br.debian.org/debian/pool/main/libc/libcap2/libcap2-bin_2.25-1_amd64.deb
    <-d  | --dest_artifactory> artifactory destination location   Example: $0 -d deb-ns1/pool/ubuntu/bionic/l/libcap2-bin/
    [--yes] Apply without need of Confirmation prompt
    [-h  | --help]  Display help.

HELP_USAGE
}

### variables definition
variable_validation () {

### extract options and their arguments into variables.
while true; do
  case "$1" in
    -h | --help)
    usage
    exit 1
    ;;
    -s | --source_debian_pkg )
    LOCAL_PKG="$2";
    shift 2
    ;;
    -d | --dest_artifactory )
    DEST_ARTIFACTORY="$2";
    shift 2
    ;;
    --yes )
    WO_CONF=1;
    shift
    ;;
    -- )
    break
    ;;
    *  )
    break
    ;;
  esac
done
    if [[ -z "${LOCAL_PKG}" ]] || [[ -z "${DEST_ARTIFACTORY}" ]]
    then
        usage
        exit 1
    fi
}

download_if_remote () {
  regex='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|].deb$'

  PKG_NAME="${LOCAL_PKG##*/}"

  if [[ $LOCAL_PKG =~ $regex ]]
  then 
    wget $LOCAL_PKG
  fi
}

### Debian package file definition
check_debian_pkg () {
  download_if_remote $LOCAL_PKG

    if [ -f "${LOCAL_PKG##*/}" ];
    then
      jfrog rt upload --deb=bionic/distro/amd64 "${LOCAL_PKG##*/}" ${DEST_ARTIFACTORY}
      echo "${LOCAL_PKG##*/} Debian package was uploaded to Artifactory"
    else
      echo "Warning!!! ${LOCAL_PKG##*/} does not exist"
    fi
}

main () {
    variable_validation $@

    echo -e    "This script will:
    1. Perform upload of Debian package file to NS1 Artifactory repository destination"

    if [ "$WO_CONF" != 1 ];
    then
        echo "Do you want to continue? [Y/n]"
            read ANSWER

            if [ ${ANSWER} != "Y" ] && [ ${ANSWER} != "Yes" ];
            then
                exit
            fi
    fi

    check_debian_pkg
 }

main $@
