#!/bin/bash
#
#  MIT License
#
#  Copyright (c) 2017 Martin Heidegger
#                https://github.com/martinheidegger/install-node
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in all
#  copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  SOFTWARE.
#
#
#  # Install [Node.js](https://nodejs.org) and [Yarn](https://yarnpkg.com) quickly in [docker](https://docker.com) files
#  
#  The `install_node.sh` script is a high-performance script for setting up Node & Yarn in docker,
#  it is fast, secure and more efficient than regular installation methods, taking
#  advantage of the way docker works.
#  
#  ## Why it is better? ⚡️
#  - You reduce the lines in your docker file to 1
#  - It downloads both Yarn and Docker in parallel - fast 
#  - It securely supports mirrors in case you have a faster mirror to download Node or Yarn.
#  - Every variable is taken directly. 
#  - It doesn't leave any files behind - the Docker image will not hold any temporary files
#  - It removes even npm & docs files to make the image even slimmer
#  
#  ## Installation Instructions 🚀
#  
#  1. Be sure that you have all dependencies (debian example): 
#      ```dockerfile
#      RUN apt-get update \
#          && apt-get install -y \
#                build-essential \
#                git \
#                curl \
#          && rm -rf /var/cache/apk/*
#      ```
#      Note: build-essential is not necessarily required, but if any node build process requires a c, c++ or
#            other library, the `yarn install` process might fail. 
#  
#  2. Either A or B
#  
#      A. Copy this file in your project and add following to your Dockerfile 
#     
#        ```dockerfile
#        ADD install_node.sh
#        RUN NODE_VERSION="v5.1.0" \
#            YARN_VERSION="v0.19.1" \
#            bash /install_node.sh \
#            && rm scripts/install_node.sh
#        ```
#  
#        This is better when you want to reduce the build time and
#        are okay with updating this script by hand.
#  
#      B. Use curl to download the file from github:
#  
#        ```dockerfile
#        RUN curl -sL https://raw.githubusercontent.com/martinheidegger/install-node/master/install_node.sh | \
#            NODE_VERSION="v5.1.0" \
#            YARN_VERSION="v0.19.1" \
#            bash
#        ``` 
#          
#        This is better when you want to make sure that this build file is up-to-date and to reduce the
#        dockerfile steps.
#  
#  ## Specifying a node mirror
#  
#  If you want to use a different mirror to download node or yarn you can specify it like:
#  
#  ```dockerfile
#  RUN NODE_MIRROR="https://nodejs.org/dist" \
#      YARN_MIRROR="https://myyarnmirror.org/dist" \
#      NODE_VERSION="v5.1.0" \
#      YARN_VERSION="v0.19.1" \
#      (curl -sL /install_node.sh | bash)
#  ```
#  
#  Note: Even though you specify a different mirror, the integration checks will run against data from the
#        original mirrors!
#  
#  ## Installation variants
#  
#  By default this script will take the 'linux-x64' variant. If you need another variant, specify it like
#  
#  ```dockerfile
#  RUN NODE_VARIANT="linux-x86" \
#      NODE_VERSION="v5.1.0" \
#      YARN_VERSION="v0.19.1" \
#      (curl -sL /install_node.sh | bash)
#  ```
#   
#  You can peek into a node dist folder like https://nodejs.org/dist/v6.9.4/ to look for the available variants.
#
#  ## Special variant "make"
#
#  If you supply the `NODE_VARIANT="make"` it will download the sources and install them directly, this is important
#  in case the binary doesn't work in operating systems such as alpine-linux.
#
#  ## Usable node
#  
#  The default node script is trimmed for production, which means files like docs or npm will be dropped! In order
#  To keep them it you can pass in: `KEEP_EXTRAS=true` and all the nice files will be kept.
#  
if [ -z "${NODE_FOLDER}" ]; then
    export NODE_FOLDER="/var/node"
fi

if [ -z "${YARN_FOLDER}" ]; then
    export YARN_FOLDER="/var/yarn"
fi

if [ -z "${NODE_MIRROR}" ]; then
    export NODE_MIRROR="https://cnpmjs.org/mirrors/node"
fi

if [ -z "${YARN_MIRROR}" ]; then
    export YARN_MIRROR="https://github.com/yarnpkg/yarn/releases/download"
fi

if [ -z "${NODE_VARIANT}" ]; then
    # Maybe better system test?
    export NODE_VARIANT="linux-x64"
fi

if [ -z "${KEEP_EXTRAS}" ]; then
    export KEEP_EXTRAS="false"
fi

missing=""
for field in \
    "NODE_VERSION"\
    "NODE_MIRROR"\
    "NODE_FOLDER"\
    "YARN_VERSION"\
    "YARN_MIRROR"\
    "YARN_FOLDER"\
    "NODE_VARIANT"\
    "KEEP_EXTRAS";
do
    if [ -z "$(printenv $field)" ]; then
    if [ -z "${missing}" ]; then
    missing="${field}"
    else
    missing="${missing}, ${field}"
    fi
    else
    echo "${field}: $(printenv $field)"
    fi
done
if [ ! -z "${missing}" ]; then
    echo "ERROR: Following environment variables required: ${missing}" >&2
    exit 1
fi

DEP_MISSING=false
(type git) || (echo "Git required for download several node packages!" >&2; export DEP_MISSING=true)
(type curl) || (echo "curl required to download everything!" >&2; export DEP_MISSING=true)
(type gpg) || (echo "GNUPG required to verify the downloads!" >&2; export DEP_MISSING=true)

if [ "${NODE_VARIANT}" == "make" ]; then
    (type python) || (echo "Python required to make node!" >&2; export DEP_MISSING=true)
    (type make) || (echo "Make required to make node!" >&2; export DEP_MISSING=true)
    (type g++) || (echo "g++ required to make node!" >&2; export DEP_MISSING=true)
else
    (type python) || (echo "WARNING: Python recommended to build some NPM packages!" >&2)
    (type make) || (echo "WARNING: make recommended to build some NPM packages!" >&2)
    (type g++) || (echo "WARNING: g++ recommended to build some NPM packages!" >&2)
fi

if [ "${DEP_MISSING}" == "true" ]; then
  exit 1
fi

get_it () {
    INSTALL_FOLDER=$(readlink -f "${INSTALL_FOLDER}" || echo "${INSTALL_FOLDER}")
    echo "Loading $1 from ${URL}"
    (cd "${INSTALL_FOLDER}" 2> /dev/null) \
        && echo "ERROR: Install folder for $1: '${INSTALL_FOLDER}' already exists" >&2 \
        && exit 1

    TMP_FOLDER="$(mktemp -d)"
    TMP_FILE_NAME="${URL##*/}"
    TMP_FILE="${TMP_FOLDER}/${TMP_FILE_NAME}"
    SHA_FILE="${TMP_FOLDER}/${SHA_URL##*/}"

    echo "Downloading ${SHA_URL} and ${URL} in parallel"
    (curl -L ${SHA_URL} > ${SHA_FILE}) 2>&1 &
    (curl -L ${URL} > ${TMP_FILE}) 2>&1 || (echo "Couldn't download ${TMP_FILE}" >&2 && exit 1)

    wait %1 || (echo "Couldn't download ${SHA_FILE}" >&2 && exit 1)

    if [ "${SHA_FILE: -4}" == ".asc" ]; then
        gpg --verify "${SHA_FILE}" "${TMP_FILE}" 2>&1 \
        || (echo "Couldn't verify ${TMP_FILE}" >&2 && exit 1) \
        || exit 1
    else 
        (cd ${TMP_FOLDER} && (cat ${SHA_FILE} | grep "${TMP_FILE_NAME}") | sha256sum -c && echo "SHASUM match") \
        || ( echo "ERROR: Downloaded $1 SHASUM doesn't match $(cat ${SHA_FILE} | grep ${TMP_FILE_NAME})" >&2 && exit 1 ) \
        || exit 1
    fi

    echo "Extracting $1 into ${TMP_FOLDER}"
    cd ${TMP_FOLDER} && tar -zxf "${TMP_FILE}"
    PARENT="$(dirname "${INSTALL_FOLDER}")"
    mkdir -p "${PARENT}"
    echo "Moving temp folder: '${TMP_FOLDER}/${ROOT}' to '${INSTALL_FOLDER}'"
    mv "${TMP_FOLDER}/${ROOT}" "${INSTALL_FOLDER}"
    rm -rf "${TMP_FOLDER}"
}

download_node () {
    NODE="node-${NODE_VERSION}"
    if [ "${NODE_VARIANT}" != "make" ]; then
       NODE="${NODE}-${NODE_VARIANT}"
    fi
    ( \
        URL="${NODE_MIRROR}/${NODE_VERSION}/${NODE}.tar.gz" \
        SHA_URL="https://nodejs.org/download/release/${NODE_VERSION}/SHASUMS256.txt" \
        INSTALL_FOLDER="${NODE_FOLDER}" \
        ROOT="${NODE}" \
        get_it "node" ) || exit 1
}

install_node () {
    if [ "${NODE_VARIANT}" == "make" ]; then
        echo "Building Node"
        HERE="$(pwd)"
        cd "${NODE_FOLDER}"
        ./configure
        apk del .build-deps
        make install
        cd "$HERE"
        rm -rf "${NODE_FOLDER}"
    else
        echo "Linking Node"
        ln -s "${NODE_FOLDER}/bin/node" /usr/local/bin/node
    fi
    
    if [ "${KEEP_EXTRAS}" != "true" ]; then
        echo "Purging node extras"
        if [ "${NODE_VARIANT}" == "make" ]; then
            rm -f /usr/local/bin/npm
            rm -rf /usr/local/lib/node_modules/npm
        else
            rm -rf \
                "${NODE_FOLDER}/lib/node_modules/" \
                "${NODE_FOLDER}/*.md" \
                "${NODE_FOLDER}/LICENSE" \
                "${NODE_FOLDER}/bin/npm" \
                "${NODE_FOLDER}/share/man"
        fi
    else
        echo "Linking NPM"
        ln -s "${NODE_FOLDER}/bin/npm" /usr/local/bin/npm
    fi
    echo "Installed Node.js: $(node -v)" || (echo "Node not properly installed" >&2 && exit 1)
}

download_yarn () {
    (curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --import --textmode) || (echo "Couldn't load the yarn public key." && exit 1)
    ( \
        URL="${YARN_MIRROR}/${YARN_VERSION}/yarn-${YARN_VERSION}.tar.gz" \
        SHA_URL="https://github.com/yarnpkg/yarn/releases/download/${YARN_VERSION}/yarn-${YARN_VERSION}.tar.gz.asc"
        INSTALL_FOLDER="${YARN_FOLDER}" \
        ROOT="dist" \
        CHECK_SHA="${YARN_SHA}" \
        get_it "yarn" ) || exit 1
}

install_yarn () {
    ln -s "${YARN_FOLDER}/bin/yarn" /usr/local/bin/yarn
    YARN_BIN="$(yarn global bin)" || exit 1
    echo "export PATH=\"\${PATH}:${YARN_BIN}\"" >> /etc/bash.bashrc
    if [ "${KEEP_EXTRAS}" != "true" ]; then
        echo "Purging yarn extras"
        rm -rf \
            "${YARN_FOLDER}/LICENSE" \
            "${YARN_FOLDER}/*.md" \
            "${YARN_FOLDER}/**/LICENSE" \
            "${YARN_FOLDER}/**/*.md" \
            "${YARN_FOLDER}/end_to_end_tests"
    fi
    echo "Installed yarn: $(yarn --version)" || (echo "Yarn not properly installed" >2 && exit 1)
}

if [[ -z "${HOME}/.gnupg" ]]; then
    export DROP_GNUGP_FOLDER="1"
fi

OUT_FOLDER="$(mktemp -d)"
echo "Downloading yarn in the background (${OUT_FOLDER})"
(download_yarn >"${OUT_FOLDER}/yarn.out" 2>"${OUT_FOLDER}/yarn.err") &
download_node || exit 1

wait %1 || ERR=$?

if [ "$DROP_GNUGP_FOLDER" == "1" ]; then
    echo "Cleaning up Gnugp folder"
    rm -rf "${HOME}/.gnupg"
fi

cat "${OUT_FOLDER}/yarn.out"
cat "${OUT_FOLDER}/yarn.err" >&2
rm -rf "${OUT_FOLDER}"

if [[ "$ERR" != "0" && "$ERR" != "" ]]; then
    echo "Error while downloading yarn" >&2
    exit 1
fi

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
install_node
install_yarn
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
