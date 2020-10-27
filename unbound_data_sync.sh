#!/bin/bash

# Dump local-zones and local-data from the local unbound DNS server instance and
# load it into remote unbound DNS servers.

# Neither of the involved servers have to be restartet, preserving cached data.

# Bail out on error.
set -e
set -o pipefail
set -u

# We need root privileges (for write access to /etc and for unbound-control).
if [[ $(id -u) -ne 0 ]] ; then 
    echo "Sorry, but you need root privileges to use this." ; 
    exit 1 ; 
fi

# ---------------
# Settings
# ---------------

# List of remote target hosts
REMOTE_HOSTS='dolores.example.net maeve.example.net bernard.example.net arnold.example.net'

# Prerequesites
LC_TIME=en_US.UTF-8
TEMP_DIR=$(mktemp --tmpdir --directory unbound-sync.XXXXXX)

# ---------------
# Main
# ---------------

echo -n "Exporting (compressed) local zones ... "
unbound-control list_local_zones | gzip -c - > "${TEMP_DIR}/local_zones.gz"
echo "Done."

echo -n "Exporting (compressed) local data .... "
unbound-control list_local_data | gzip -c - > "${TEMP_DIR}/local_datas.gz" 
echo "Done."

for this_host in ${REMOTE_HOSTS}; 
do 

    echo -n "Creating a working directory on $this_host ... "
    REMOTE_TEMP_DIR=$(ssh "$this_host" 'TEMP_DIR=$(mktemp -p /tmp -d unbound-sync.XXXXXX) && echo $TEMP_DIR')
    echo "Done."

    if [ -s "${TEMP_DIR}/local_zones.gz" ]; then

        echo -n "Transferring (compressed) local zones to $this_host ... "
        scp "${TEMP_DIR}/local_zones.gz" "${this_host}:${REMOTE_TEMP_DIR}/"
        echo "Done."

        echo -n "Decompressing local zones on $this_host ... "
        # shellcheck disable=2029
        ssh "$this_host" "gzip --decompress ${REMOTE_TEMP_DIR}/local_zones.gz"
        echo "Done."

        echo -n "Importing local zones on $this_host ... "
        # shellcheck disable=2029
        ssh "$this_host" "unbound-control local_zones < ${REMOTE_TEMP_DIR}/local_zones && rm ${REMOTE_TEMP_DIR}/local_zones"
        echo "Done."

    fi

    if [ -s "${TEMP_DIR}/local_datas" ]; then

        scp "${TEMP_DIR}/local_datas.gz" "${this_host}:${REMOTE_TEMP_DIR}/"
        # shellcheck disable=2029
        ssh "$this_host" "gzip --decompress ${REMOTE_TEMP_DIR}/local_datas.gz"
        # shellcheck disable=2029
        ssh "$this_host" "unbound-control local_datas < ${REMOTE_TEMP_DIR}/local_datas && rm ${REMOTE_TEMP_DIR}/local_datas"

    fi

    echo -n "Cleaning up working directory on $this_host ... "
    # shellcheck disable=2029
    ssh "$this_host" "rmdir $REMOTE_TEMP_DIR"
    echo "Done."

done

rm -rf "$TEMP_DIR"

echo
echo 'All done.'
echo 'Have a nice day.'
