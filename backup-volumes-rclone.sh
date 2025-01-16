#!/usr/bin/env zsh

# GOALS:
#  - program execution should be idempotent
#  - Backup docker volumes as tar files
#  - Encrypt them
#  - Upload the encrypted file on Mega
#  - Handle errors


#Volumes we want to backup
typeset -A volumes=()

volumes[changedetection]="/datastore"
volumes[freshrss]="/var/www/FreshRSS"
volumes[hoarder]="/data"
volumes[mealie]="/app/data"
volumes[mealie-db]="/var/lib/postgresql/data"
volumes[traefik]="/letsencrypt"
volumes[ttrss-db]="/var/lib/postgresql/data"
volumes[ttrss]="/srv/ttrss/plugins.local"
volumes[vikunja]="/app/vikunja/files"
volumes[vikunja-db]="/var/lib/postgresql/data"

# volumes["ryot-db"]="/var/lib/postgresql/data"

#Files and Folders here
homeserver="${HOME}/homeserver"
tempBackupFolder="/tmp/bkp"

source ${homeserver}/backup-config.sh

notify() {
  local title="$1"
  local body="$2"
  local url="telegram://${TG_API_KEY}@telegram?channels=${TG_CHANNEL}&parseMode=HTML"
  local msg=$(echo -e "<i>$title</i>\n$body")
  docker run --rm containrrr/shoutrrr send -u "$url" --message "$msg"
}

# 1. Create the folder and check it's empty (folder  could be already there)
mkdir ${tempBackupFolder} > /dev/null 2>&1
chmod 755 ${tempBackupFolder}
if [[ "$(ls -A ${tempBackupFolder})" != "" ]]; then
    echo "Folder not empty... Stopping"
    notify "Backup failed" "Backup folder is not empty"
    exit 1
fi

# 5. Run backups of docker containers
backupDate=$(date +%F)

cd ${homeserver}
docker compose --progress quiet stop

for container folder in ${(kv)volumes}; do
  echo -n "Backing up ${container}..."
  docker run --rm --volumes-from ${container} -v ${tempBackupFolder}:/backup ubuntu tar czvf /backup/${container}_${backupDate}.tar.gz ${folder} > /dev/null 2>&1
  echo "OK!"
done

docker compose --progress quiet up -d
cd -

rclone copy ${tempBackupFolder}/ secret_pineco:${backupDate}/

# 8. Remove plain files
rm -rf ${tempBackupFolder}

# 11. Inform user
notify "Backup successful" "A backup has been performed on ${backupDate}"
