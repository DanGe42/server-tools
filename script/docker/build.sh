#!/bin/sh
# This script builds Docker containers with some sane defaults.
#
# Usage notes:
#   $0 docker_tag directory
#
# - docker_tag: tag to supply to `docker build -t $tag`
# - directory: directory containing Dockerfile

# Any unhandled errors prevent this script from continuing
set -o errexit

# Exit of any portion of a pipe fails
set -o pipefail

if [ -z "$1" ] || [ -z "$2" ]
then
    echo "Usage: $0 docker_tag directory" 2> /dev/null
    exit 1
fi
container_tag="$1"
directory="$2"

# Raise error for unset variables
set -o nounset

if [ ! -f "$directory/Dockerfile" ]
then
    echo "$directory does not contain a Dockerfile" 2> /dev/null
    exit 1
fi

# Get a copy of dumb-init, if necessary
# dumb-init sets up an init process
# https://github.com/Yelp/dumb-init
DUMB_INIT_VERSION=v1.2.0
DUMB_INIT_FILE=dumb-init_1.2.0_amd64
DUMB_INIT_URL=https://github.com/Yelp/dumb-init/releases/download/$DUMB_INIT_VERSION/$DUMB_INIT_FILE

if [ ! -f $DUMB_INIT_FILE ]
then
    curl -o $DUMB_INIT_FILE -L --fail $DUMB_INIT_URL
    chmod +x $DUMB_INIT_FILE
else
    echo "Skipping dumb-init download" 2> /dev/null
fi

# Test that we really downloaded the dumb-init executable. This mitigates a
# potential issue where we may encounter a non-200 non-failing HTTP response in
# the earlier curl command that ends up saving something to this file that isn't
# an executable (e.g. an HTML page).
file $DUMB_INIT_FILE | grep ELF

# Create a temporary workspace and copy the contents of supplied directory to it
tmpdir=${TMPDIR:-/tmp}
workspace=$(mktemp -d "$tmpdir/${container_tag}_workspace.XXXXX")
cp -r "$directory"/* "$workspace/"

# Now also add dumb-init
# We hide it in .bin because it's unlikely that most projects would actually put
# binstubs in a hidden .bin folder. This also puts it out of the way so that
# the developer can elect not to use dumb-init in the Docker container.
mkdir "$workspace/.bin"
cp $DUMB_INIT_FILE "$workspace/.bin/dumb-init"

docker build -t "$container_tag" "$workspace"

if grep EXPOSE "$directory/Dockerfile" > /dev/null
then
    echo "This build container EXPOSEs a few ports." \
        "You can map in your \`docker run\` command by adding multiple" \
        "-p flags as follows: -p [host_port1]:[exposed1] ..." \
        "-p [host_portN]:[exposedN]" 2> /dev/null
    grep EXPOSE "$directory/Dockerfile" 2> /dev/null
fi
