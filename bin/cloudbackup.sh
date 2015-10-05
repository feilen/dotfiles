#!/bin/bash

#Must be set up for passwordless SSH
REMOTEUSER=backup

REMOTEHOST=$1

MYSQLUSERNAME=$2

MYSQLPASSWORD=$3

BACKUPDIR=$4

#Backup mysql to /tmp/mysqldump.bak
ssh ${REMOTEUSER}@${REMOTEHOST} "mysqldump --lock-tables --protocol=socket -S /run/mysqld/mysqld.sock -u $MYSQLUSERNAME --password=${MYSQLPASSWORD} owncloud > /tmp/mysqldump.bak"
rsync -Aax -e ssh --delete ${REMOTEUSER}@${REMOTEHOST}:/tmp/mysqldump.bak ${REMOTEUSER}@${REMOTEHOST}:/usr/share/webapps/owncloud/data ${REMOTEUSER}@${REMOTEHOST}:/etc/webapps/owncloud/config "${BACKUPDIR}"
ssh ${REMOTEUSER}@${REMOTEHOST} "rm -f /tmp/mysqldump.bak"

