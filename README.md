# Install [Node.js](https://nodejs.org) and [Yarn](https://yarnpkg.com) quickly in [docker](https://docker.com) files

The `install_node.sh` script is a high-performance script for setting up Node & Yarn in docker,
it is fast, secure and more efficient than regular installation methods, taking
advantage of the way docker works.

## Why it is better? ⚡️
- You reduce the lines in your docker file to 1
- It downloads both Yarn and Node in parallel - fast 
- It securely supports mirrors in case you have a faster mirror to download Node or Yarn.
- Every variable is taken directly. 
- It doesn't leave any files behind - the Docker image will not hold any temporary files
- It removes even npm & docs files to make the image even slimmer

## Installation Instructions 🚀

1. Be sure that you have all dependencies (debian example): 
    ```dockerfile
    RUN apt-get update \
        && apt-get install -y \
              build-essential \
              git \
              curl \
        && rm -rf /var/cache/apk/*
    ```
    Note: build-essential is not necessarily required, but if any node build process requires a c, c++ or
          other library, the `yarn install` process might fail. 

2. Either A or B

    A. Copy this file in your project and add following to your Dockerfile 
   
      ```dockerfile
      ADD install_node.sh
      RUN NODE_VERSION="v5.1.0" \
          YARN_VERSION="v0.19.1" \
          bash /install_node.sh \
          && rm scripts/install_node.sh
      ```

      This is better when you want to reduce the build time and
      are okay with updating this script by hand.

    B. Use curl to download the file from github:

      ```dockerfile
      RUN curl -sL https://raw.githubusercontent.com/martinheidegger/install-node/master/install_node.sh  | \
          NODE_VERSION="v5.1.0" \
          YARN_VERSION="v0.19.1" \
          bash
      ``` 
        
      This is better when you want to make sure that this build file is up-to-date and to reduce the
      dockerfile steps.

## Specifying a node mirror

If you want to use a different mirror to download node or yarn you can specify it like:

```dockerfile
RUN NODE_MIRROR="https://nodejs.org/dist" \
    YARN_MIRROR="https://myyarnmirror.org/dist" \
    NODE_VERSION="v5.1.0" \
    YARN_VERSION="v0.19.1" \
    (curl -sL /install_node.sh | bash)
```

Note: Even though you specify a different mirror, the integration checks will run against data from the
      original mirrors!

## Installation variants

By default this script will take the 'linux-x64' variant. If you need another variant, specify it like

```dockerfile
RUN NODE_VARIANT="linux-x86" \
    NODE_VERSION="v5.1.0" \
    YARN_VERSION="v0.19.1" \
    (curl -sL /install_node.sh | bash)
```
 
You can peek into a node dist folder like https://nodejs.org/dist/v6.9.4/ to look for the available variants.

## Special variant "make"

If you supply the `NODE_VARIANT="make"` it will download the sources and install them directly, this is important
in case the binary doesn't work in operating systems such as alpine-linux.

## Usable node

The default node script is trimmed for production, which means files like docs or npm will be dropped! In order
To keep them it you can pass in: `KEEP_EXTRAS=true` and all the nice files will be kept.
