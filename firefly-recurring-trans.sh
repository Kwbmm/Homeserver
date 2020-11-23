#!/usr/bin/env bash
docker exec --user www-data firefly /usr/local/bin/php /var/www/html/artisan firefly-iii:cron
docker exec --user www-data firefly /usr/local/bin/php /var/www/html/artisan cache:clear
