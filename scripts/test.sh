#!/usr/bin/env bash
set -e -o pipefail

random_container_name() {
    shuf -zer -n10  {A..Z} {a..z} {0..9} | tr -d '\0'
}

container_type="gitolite"
container_name=$(random_container_name)

echo "Starting ${container_type:?} container ${container_name:?} to run tests in the foreground ..."
docker run \
    --name ${container_name:?} \
    --detach \
    --rm \
    --publish 127.0.0.1:2222:2222 \
    ${IMAGE:?}

echo "Waiting for the ${container_type:?} container ${container_name:?} to finish starting up ..."
sleep 10

echo "Running tests against the ${container_type:?} container ${container_name:?} ..."

echo "All tests passed against the ${container_type:?} container ${container_name:?} ..."

echo "Stopping the ${container_type:?} container ${container_name:?} ..."
docker stop ${container_name:?} --time 5 2>/dev/null 1>&2 || /bin/true
docker kill ${container_name:?} 2>/dev/null 1>&2 || /bin/true
