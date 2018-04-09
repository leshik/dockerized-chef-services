#!/bin/bash

# Configurable shell environment variables:
# CHEF_SERVER_DOCKER_ORIGIN - denotes the docker origin (dockerhub ID) or default to `chefserverofficial`
# CHEF_SERVER_VERSION -  the version identifier tag on the packages
# HOST_IP - the IP address of the docker host. 172.17.0.1 is commonly the docker0 interface which is fine
# AUTOMATE_ENABLED - enable the Automate data collector (true or false)
# AUTOMATE_SERVER - the IP address or hostname of the Automate server
# AUTOMATE_TOKEN - the token for the Automate server data collector
# DATA_MOUNT - the mount point for the data
# USER_ID - the user ID to use (numeric)
# GROUP_ID - the group ID to use (numeric)

if [ -f "env.sh" ]; then
 echo "Setting ENVIRONMENT variables"
 . ./env.sh
fi

for svc in postgresql chef-server-ctl elasticsearch oc_id bookshelf oc_bifrost oc_erchef chef-server-nginx; do
  # NOTE: If launching all the services at once from a down state, then clearing out `/hab/sup` ensures
  # a clean slate so that the ring can be established. This guarantees ring recovery when things go sideways..
  # Do not do this for (re-)starting individual services as it will lead to exclusion of the service from the ring.
  sudo rm -rf "${DATA_MOUNT:-/mnt/hab}/${svc}_sup"

  dirs="${DATA_MOUNT:-/mnt/hab}/${svc}_svc ${DATA_MOUNT:-/mnt/hab}/${svc}_sup"
  echo "Ensuring $svc directories exist ($dirs)"
  sudo mkdir -p $dirs
  sudo chown -R $USER_ID:$GROUP_ID $dirs
done

# postgresql

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for postgresql"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/postgresql_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="postgresql" \
  --env="HAB_POSTGRESQL=[superuser]
name = 'hab'
password = 'chefrocks'
" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/postgresql_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/postgresql_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/postgresql:${CHEF_SERVER_VERSION:-latest}

# chef-server-ctl

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for chef-server-ctl"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/chef-server-ctl_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="chef-server-ctl" \
  --env="HAB_CHEF_SERVER_CTL=[chef_server_api]
ip = \"${HOST_IP:-172.17.0.1}\"
ssl_port = "8443"
[secrets.data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/chef-server-ctl_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/chef-server-ctl_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/chef-server-ctl:${CHEF_SERVER_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9650 --listen-http 0.0.0.0:9660

# elasticsearch

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for elasticsearch"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/elasticsearch_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="elasticsearch" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/elasticsearch_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/elasticsearch_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --ulimit nofile=65536:65536 \
  --detach=true \
  ${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/elasticsearch5:${CHEF_SERVER_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9651 --listen-http 0.0.0.0:9661

# oc_id

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for oc_id"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/oc_id_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="oc_id" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/oc_id_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/oc_id_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/oc_id:${CHEF_SERVER_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9652 --listen-http 0.0.0.0:9662

# bookshelf

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for bookshelf"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/bookshelf_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="bookshelf" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/bookshelf_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/bookshelf_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/bookshelf:${CHEF_SERVER_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9653 --listen-http 0.0.0.0:9663

# oc_bifrost

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for oc_bifrost"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/oc_bifrost_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="oc_bifrost" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/oc_bifrost_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/oc_bifrost_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/oc_bifrost:${CHEF_SERVER_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9654 --listen-http 0.0.0.0:9664

# oc_erchef

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for oc_erchef"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/oc_erchef_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="oc_erchef" \
  --env="HAB_OC_ERCHEF=[data_collector]
enabled = ${AUTOMATE_ENABLED:-false}
server = \"${AUTOMATE_SERVER:-localhost}\"
port = 443
[chef_authn]
keygen_cache_workers = 2
keygen_cache_size = 10
keygen_start_size = 0
keygen_timeout = 20000
" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/oc_erchef_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/oc_erchef_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/oc_erchef:${CHEF_SERVER_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind bookshelf:bookshelf.default --bind oc_bifrost:oc_bifrost.default --bind database:postgresql.default --bind elasticsearch:elasticsearch5.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9655 --listen-http 0.0.0.0:9665

# chef-server-nginx

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for chef-server-nginx"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/chef-server-nginx_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="chef-server-nginx" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/chef-server-nginx_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/chef-server-nginx_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/chef-server-nginx:${CHEF_SERVER_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind oc_erchef:oc_erchef.default --bind oc_bifrost:oc_bifrost.default --bind oc_id:oc_id.default --bind bookshelf:bookshelf.default --bind elasticsearch:elasticsearch5.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9656 --listen-http 0.0.0.0:9666
