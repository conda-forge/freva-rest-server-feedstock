#!/usr/bin/env sh

set  -o nounset -o pipefail -o errexit
PGK_NAME=freva-rest-server
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

create_systemd_units(){
    # Create service units.
    #
    cat << EOF > template.j2
[Unit]
Description={{DESCRIPTION}}
After={{AFTER}}

[Service]
Type=notify
ProtectSystem=full
PermissionsStartOnly=true
NoNewPrivileges=true
ProtectHome=true
KillSignal=SIGTERM
SendSIGKILL=no
Restart=on-abort
ExecStartPre=/bin/sh -c "systemctl unset-environment _WSREP_START_POSITION"
ExecStartPre={{EXEC_START_PRE}}
ExecStart={{EXEC_START}}
ExecStartPost=/bin/sh -c "systemctl unset-environment _WSREP_START_POSITION"
UMask=007

# Uncomment the following line to fine grain the sytemd unit behaviour
#
# Set the user name and user group
# User=$(whoami)
# Group=$(id -g)
#
# Set an environment file with default configuration
EnvironmentFile=$PREFIX/share/$PKG_NAME/config.ini

[Install]
WantedBy=multi-user.target
EOF
    mkdir -p $PREFIX/share/$PKG_NAME/systemd/
    #MYSQL SERVER
    mysql_unit=$(cat template.j2|sed \
    -e "s|{{DESCRIPTION}}|MariaDB database server|g" \
    -e "s|{{AFTER}}|network.target|g" \
    -e "s|{{EXEC_START_PRE}}|$PREFIX/libexec/$PKG_NAME/scripts/init-mysqld |g" \
    -e "s|{{EXEC_START}}|$PREFIX/bin/mysqld --bind-address=0.0.0.0|g")
    echo "$mysql_unit" | tee "$PREFIX/share/$PKG_NAME/systemd/mysqld.service" > /dev/null

    #APACHE SOLR
    solr_unit=$(cat template.j2|sed \
    -e "s|{{DESCRIPTION}}|Apache solr server|g" \
    -e "s|{{AFTER}}|network.target|g" \
    -e "s|{{EXEC_START_PRE}}|$PREFIX/libexec/$PKG_NAME/scripts/init-solr |g" \
    -e "s|{{EXEC_START}}|$PREFIX/bin/solr -f --force |g")
    echo "$solr_unit" | tee "$PREFIX/share/$PKG_NAME/systemd/solr.service" > /dev/null


    #MONGO DB
    mongo_unit=$(cat template.j2|sed \
    -e "s|{{DESCRIPTION}}|MongoDB server|g" \
    -e "s|{{AFTER}}|network.target|g" \
    -e "s|{{EXEC_START_PRE}}|$PREFIX/libexec/$PKG_NAME/scripts/init-mongo |g" \
    -e "s|{{EXEC_START}}|$PREFIX/bin/mongod -f \$CONDA_PREFIX/share/$PKG_NAME/mongodb/mongod.conf |g")
    echo "$mongo_unit" | tee "$PREFIX/share/$PKG_NAME/systemd/mongo.service" > /dev/null

    #Redis
    redis_unit=$(cat template.j2|sed \
    -e "s|{{DESCRIPTION}}|Redis server|g" \
    -e "s|{{AFTER}}|network.target|g" \
    -e "s|{{EXEC_START_PRE}}|$PREFIX/libexec/$PKG_NAME/scripts/init-redis|g" \
    -e "s|{{EXEC_START}}|$PREFIX/bin/redis-server /tmp/redis.conf|g")
    echo "$redis_unit" | tee "$PREFIX/share/$PKG_NAME/systemd/redis.service" > /dev/null

rm -r $TEMP_DIR
}


create_systemd_units
