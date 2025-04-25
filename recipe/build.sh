#!/usr/bin/env bash
set  -o nounset -o pipefail -o errexit

TEMP_DIR=$(mktemp -d)
PKG_NAME=freva-rest-server

# Define an exit function
exit_func(){
    rm -rf $TEMP_DIR
    exit $1
}

# Trap exit signals to ensure cleanup is called
trap 'exit_func 1' SIGINT SIGTERM ERR


install_server(){
    # Install the rest server
    #
    $PREFIX/bin/python -m pip install ./freva-rest -vv --prefix $PREFIX \
        --root-user-action ignore --no-deps --no-build-isolation

}

setup_config() {
    # Setup additional configuration
    cd $TEMP_DIR
    git clone --recursive -b dev-ops-crazyness https://github.com/FREVA-CLINT/freva-service-config.git
    mkdir -p $PREFIX/etc/profile.d $PREFIX/libexec/$PKG_NAME
    echo "#!/usr/bin/env bash" > $PREFIX/etc/profile.d/freva-rest-server.sh
    echo "" >> $PREFIX/etc/profile.d/$PKG_NAME.sh
    echo "DATA_DIR=\${API_DATA_DIR:-$PREFIX/var/$PKG_NAME/\$SERVICE}" >> $PREFIX/etc/profile.d/freva-rest-server.sh
    echo "LOG_DIR=\${API_LOG_DIR:-$PREFIX/var/log/$PKG_NAME/\$SERVICE}" >> $PREFIX/etc/profile.d/freva-rest-server.sh
    echo "CONFIG_DIR=\${API_CONFIG_DIR:-$PREFIX/share/$PKG_NAME/\$SERVICE}" >> $PREFIX/etc/profile.d/freva-rest-server.sh
    echo "" >> $PREFIX/etc/profile.d/freva-rest-server.sh
    echo "" >> $PREFIX/etc/profile.d/freva-rest-server.sh
    echo "mkdir -p \$DATA_DIR \$LOG_DIR \$CONFIG_DIR" >> $PREFIX/etc/profile.d/freva-rest-server.sh
    echo "USER=\$(whoami)" >> $PREFIX/etc/profile.d/freva-rest-server.sh

    for service in mongo mysql solr redis;do
        mkdir -p $PREFIX/var/$PKG_NAME/$service
        mkdir -p $PREFIX/var/log/$PKG_NAME/$service
        mkdir -p $PREFIX/share/$PKG_NAME/$service/
        cp freva-service-config/$service/init-$service $PREFIX/libexec/$PKG_NAME/
        for suffix in txt xml sql;do
            cp freva-service-config/$service/*.$suffix $PREFIX/share/$PKG_NAME/$service/ 2> /dev/null || true
        done
        cp freva-service-config/docker-scripts/healthchecks.sh $PREFIX/libexec/$PKG_NAME/
        chmod +x $PREFIX/libexec/$PKG_NAME/*
        rm freva-service-config/$service/requirements.txt
    done
    cat <<EOI > $PREFIX/bin/start-freva-service
#!/usr/bin/env bash
# Start services for the freva-rest-api
#
set -o nounset -o pipefail -o errexit

SERVICE=\${SERVICE:-}
print_help() {
  cat <<EOF
Usage: $(basename "\$0") [OPTIONS]

Start the micro services of the Freva RestAPI.

Options:
  -s, --service <name>   Name of the service (mongo, mysql, redis, solr)
  -h, --help             Show this help message and exit
EOF
}

while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -s|--service)
      SERVICE="\$2"
      shift 2
      ;;
    --service=*)
      SERVICE="\${1#*=}"
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    redis|mysql|mongo|solr)
      SERVICE=\$1
      shift
      ;;
    *)
      echo "❌ Unknown argument: \$1" >&2
      print_help
      exit 1
      ;;
  esac
done

# Start the selected service
SERVICE_SCRIPT=$PREFIX/libexec/$PKG_NAME/init-\$SERVICE
PREFIX=$PREFIX
if [ ! -f "\$SERVICE_SCRIPT" ];then
    echo "❌ No such service: \$SERVICE >&2"
fi
export CONDA_PREFIX=$PREFIX
bash \$SERVICE_SCRIPT
EOI
    chmod +x $PREFIX/bin/start-freva-service


}

#install_server
setup_config
exit_func 0
