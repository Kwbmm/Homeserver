# Docker self-hosted homeserver 

This is my personal repository of my docker services that I self-host on my Raspberr Pi 3.

The services are deployed through a docker-compose file. The following services are now deployed:

## Exposed services

  - Tiny Tiny RSS
  - Firefly III
  - Gotify

Requests are routed and handled through Traefik reverse proxy.

DuckDNS is used as a dynamic DNS provider and the relative docker service is used to keep my IP address up to date so that my services are always reachable through my DuckDNS subdomain.

Let's Encrypt is used to secure the connection to these services through free valid SSL certificates. Let's Encrypt is integrated into Traefik, which makes managing the SSL certificate part much easier.

## Internal services

  - Traefik Dashboard
  - Nodered
  - Watchtower

Traefik dashboard is used to keep an eye on the state of routing and services.

Node-Red is used to run some automation tasks.

Watchtower keeps all the containers (itself as well) up to date automatically. Makes use of Gotify to notify me when an update occurs.

## Other

  - `firefly-recurring-trans.sh` is a script file run through a cron job to trigger the processing of firefly recurring transaction that I have set up in my firefly instance. 
  - `backup-volumes.sh` => **To be publish** Backs up the volumes of the services to MEGA. Volumes are encrypted first with `gocryptfs` and then uploaded through `mega-cmd`. Status of backups is controlled through gotify notifications.