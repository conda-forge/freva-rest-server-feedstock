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
    export CONDA_PREFIX=$PREFIX
    curl https://raw.githubusercontent.com/FREVA-CLINT/freva-service-config/refs/heads/main/conda-services/create.sh | bash
}

install_server
setup_config
exit_func 0
