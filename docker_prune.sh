#!/bin/bash
#
# Detect and clean up old docker images
#
# Designed to work with a minimal set of tools *and* support older docker versions (i,e. lacks working prune commands)
#
# https://github.com/btasker/tidy_old_docker_images
#
# B Tasker, 2021
#


IGNORE_NAMES=${IGNORE_NAMES:-"NOMATCH"}
AGE_THRESHOLD=${AGE_THRESHOLD:-30}

datediff() {
    d1=$(date -d "$1" +%s)
    d2=$(date -d "$2" +%s)
    echo $(( (d1 - d2) / 86400 )) # days
}


find_candidates() {

    DOCKER_DIR=`[[ -d /var/lib/docker/image/overlay2 ]] && echo /var/lib/docker/image/overlay2 || echo /var/lib/docker/image/overlay`

    NOW=`date +'%Y-%m-%d'`
    cat $DOCKER_DIR/repositories.json  | jq '.Repositories | to_entries | .[].value | to_entries | .[].value' | sort | uniq | tr -d '"' | while read -r imghash
    do
        hsh=${imghash##*:}
        hshmec=${imghash%%:*}
        created=`cat $DOCKER_DIR/imagedb/content/$hshmec/$hsh | jq '.created' | tr -d '"'`
        shorthsh=`echo $hsh | cut -c1-7`
        age=`datediff $NOW $created`

        # This has a head because there will be 2 entries if it's also latest
        name=`cat $DOCKER_DIR/repositories.json  | jq . | grep "$hshmec:$hsh" | head -n1 | awk -v IFS=: '{print $1}' | tr -d '":' | cut -d/ -f2`

        echo "$name" | grep -P "($IGNORE_NAMES)" 2>&1 >/dev/null
        if [[ "$?" == "0" ]]
        then
            # Ignore these, removing them causes tears
            >&2 echo "Cowardly refusing to remove $name"
            continue
        fi

        if [[ $age -gt $AGE_THRESHOLD ]]
        then
            # Check if it's currently running
            docker inspect --format='{{.Image}}' $(docker ps -q) | grep -P "^$hshmec:$hsh\$" 2>&1 >/dev/null
            if [[ "$?" == "1" ]]
            then
                # It's not currently running
                #
                # Long hashes are ugly, but prevent collisions
                echo "$hsh: ($name) $created  ($age days old)"
            else
                >&2 echo "Not removing running $hsh"
            fi
        fi
    done
}


function kill_em_all(){
    kill_list=`find_candidates`

    # Require manual confirmation for now

    IFS=$'\n'
    for line in $kill_list
    do

        hash=`echo $line | cut -d\: -f1`
        echo $line
        read -p "Enter y to kill this image: " confirm
        if [[ "$confirm" == "y" ]]
        then
            docker rmi "$hash"
        else
            echo "Not killing"
        fi
    done
}


function usage(){

cat << EOM
$0 [-l|-k]


-l          List images available to be pruned
-k          Prune containers

Env vars:

    IGNORE_NAMES            Container names to ignore, pipe seperated
    AGE_THRESHOLD           Minimum age of containers to kill


EOM
}

if [[ "$1" == "-l" ]]
then
    echo "Would remove"
    find_candidates
elif [[ "$1" == "-k" ]]
then
    kill_em_all
else
    usage
fi



