Docker Image Tidy
===================

Check for docker images that are no longer used, and are over a certain age then list or delete them.

This works like `docker image prune` except it works on systems where prune is unavailable for whatever reason.



### Usage

Usage is simple:

    -l          List images available to be pruned
    -k          Prune containers

    Env vars:

        IGNORE_NAMES            Container names to ignore, pipe seperated
        AGE_THRESHOLD           Minimum age of containers to kill


Example

    export IGNORE_NAMES='myrootimg|dnshandler'
    ./docker_prune.sh -l # List candidates
    ./docker_prune.sh -k # Delete them
