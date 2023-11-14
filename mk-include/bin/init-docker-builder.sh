#!/bin/bash

DOCKER_BUILDER_INSTANCE=$1
shift

# Depending on our current platform, we have to setup emulatation for the opposite architecture (amd64 -> arm64)
BINFMT_MISC=""
PLATFORM=""
case $(uname -m) in
    x86_64|amd64)  PLATFORM="arm64"; BINFMT_MISC="qemu-aarch64" ;;
    aarch64|arm64) PLATFORM="amd64"; BINFMT_MISC="qemu-x86_64" ;;
    *) (echo "Unsupported Platform: $(uname -m)" && exit 1) ;;
esac

# binfmt is now installed automatically in CI AMIs: https://github.com/confluentinc/ci-build-agent-infra/pull/494
if [ -f "/proc/sys/fs/binfmt_misc/$BINFMT_MISC" ]; then
  echo "Installing $PLATFORM emulation skipped as it is already installed..."
else
  echo "Installing $PLATFORM emulation"
  docker run --privileged --rm tonistiigi/binfmt --install $PLATFORM > /dev/null
fi

(docker buildx use "$DOCKER_BUILDER_INSTANCE" >& /dev/null \
  && echo "Using existing docker builder instance: $DOCKER_BUILDER_INSTANCE") \
  || (echo "Creating docker builder instance: $DOCKER_BUILDER_INSTANCE" \
      && docker buildx create --use --name "$DOCKER_BUILDER_INSTANCE")

# in some cases we have noticed it takes a few seconds for all supported
# architectures to show up in the builder instance inspect output
MAX=60;r=0
while [ $r -lt $MAX ] ; do
  docker buildx inspect --bootstrap "$DOCKER_BUILDER_INSTANCE" | grep linux/$PLATFORM > /dev/null && break
  r=$(( r + 1 ))
  echo "Waiting for builder instance platforms to populate... [$r/$MAX]"
  sleep 1
done

[ $r -lt $MAX ] || (echo "Failed to detect linux/$PLATFORM support in docker builder instance" && exit 1)

