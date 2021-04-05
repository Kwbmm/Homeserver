#!/usr/bin/env bash
# GOALS:
#  - program execution should be idempotent
#  - Backup docker volumes as tar files
#  - Encrypt them
#  - Upload the encrypted file on Mega
#  - Handle errors


#Volumes we want to backup
declare -A volumes
volumes["traefik"]="/letsencrypt"
volumes["ttrss-db"]="/var/lib/postgresql/data"
volumes["ttrss"]="/srv/ttrss/plugins.local"
volumes["firefly"]="/var/www/html/storage/upload"
volumes["firefly-db"]="/var/lib/postgresql/data"
volumes["gotify"]="/app/data"
volumes["node-red"]="/data"

#Files and Folders here
homeserver="/home/pi/homeserver"
backupFolder="/home/pi/backup"
tempBackupFolder="/tmp/bkp"
encryptedFolder="/home/pi/encryptedVolumesOnMega"
gocryptfsconfigs=("gocryptfs.conf" "gocryptfs.diriv") 

source ${homeserver}/backup-config.sh

array_contains () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

notify() {
  local title="$1"
  local body="$2"

  curl "https://${GOTIFY_URL}/message?token=${GOTIFY_API_KEY}" -F "title=${title}" -F "message=${body}"
}

# 1. Create the folder and check it's empty (folder  could be already there)
mkdir ${backupFolder} > /dev/null 2>&1
chmod 755 ${backupFolder}
if [[ "$(ls -A ${backupFolder})" != "" ]]; then
    echo "Folder not empty... Stopping"
    notify "Backup failed" "Backup folder is not empty"
    exit 1
fi

mkdir ${tempBackupFolder} > /dev/null 2>&1
if [[ "$(ls -A ${tempBackupFolder})" != "" ]]; then
    echo "Folder not empty... Stopping"
    notify "Backup failed" "Temporary backup folder is not empty"
    exit 1
fi

# 2. Check that the encrypted folder exists. If not, log error, stop and exit
if [[ ! -d "${encryptedFolder}" ]]; then
    echo "Encrypted folder doesn't exist... Stopping"
    notify "Backup failed" "Encrypted folder doesn't exist"
    exit 1
else
    for f in $(ls "${encryptedFolder}"); do
        array_contains "${f}" "${gocryptfsconfigs[@]}"
        if [[ "$?" -eq 1 ]]; then
            echo "Missing init files. Encrypted folder is not initialized... Stopping"
            notify "Backup failed" "No init files found. Encrypted folder is not initialized"
            exit 1
        fi
    done
fi

# 4. If the folder exists, link it to the backup folder
gocryptfs -extpass "echo ${ENCRYPTED_FOLDER_PSW}" ${encryptedFolder} ${backupFolder}
gocrypt_return=$?
if [[ ${gocrypt_return} != "0" ]]; then
  echo "Gocrypt process failed - Error ${gocrypt_return}"
  notify "Backup failed" "Gocrypt process failed - Error ${gocrypt_return}"
  exit 1
fi

is_mounted=$(cat /proc/mounts | grep -q "${encryptedFolder}" ; echo "$?")
if [[ ${is_mounted} != "0" ]]; then
  echo "Mounting failed"
  notify "Backup failed" "Failed mounting encrypted folder"
  exit 1
fi

# 5. Run backups of docker containers
backupDate=$(date +%F)

cd ${homeserver}
docker-compose stop
for container in "${!volumes[@]}"; do
  echo -n "Backing up ${container}..."
  docker run --rm --volumes-from ${container} -v ${tempBackupFolder}:/backup ubuntu tar czvf /backup/${container}_${backupDate}.tar.gz ${volumes[$container]} > /dev/null 2>&1
  echo "OK!"
done
docker-compose up -d
cd -

echo -n "Moving files in ${tempBackupFolder} to ${backupFolder}..."
mv ${tempBackupFolder}/*gz ${backupFolder}/
echo "OK!"

# 6. Wait until all files have been encrypted
# We should find a way to discover when encryption is over..


# 7. Upload files to mega
mega-login "${MEGA_MAIL}" "${MEGA_PSW}"
mega-mkdir ${backupDate}

for encFile in $(ls ${encryptedFolder} | grep -v "gocryptfs"); do
  mega-put "${encryptedFolder}/${encFile}" "${backupDate}"
done

mega-logout

# 8. Remove plain files
rm -rf ${backupFolder}/*

# 9. Unmount plain
fusermount -u ${backupFolder}

# 10. Delete plain folder
rmdir ${backupFolder}

# 11. Inform user
notify "Backup successful" "A backup has been performed on ${backupDate}"
