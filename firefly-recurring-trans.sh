#!/usr/bin/env bash

docker exec firefly /usr/local/bin/php /var/www/firefly-iii/artisan firefly-iii:cron
docker exec firefly /usr/local/bin/php /var/www/firefly-iii/artisan cache:clear
