#!/bin/bash

JQ="/usr/bin/jq"
CURL="/usr/bin/curl"
WORKER="$TOOL/worker"

# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with job finish

HEALTH="/tmp/healthz"

runner() {
    echo "Stop this container."
    exit 1
}

declare -a RESPONSE=()

if ! [ -v ENVIRONMENT_PLANNER_USERNAME ] ; then
    RESPONSE+=("environment: Specifies the email.")
fi

if ! [ -v ENVIRONMENT_PLANNER_PASSWORD ] ; then
    RESPONSE+=("environment: Specifies the password.")
fi

if ! [ -v ENVIRONMENT_PLANNER_APIQUEUE ] ; then
    RESPONSE+=("environment: Specifies the API to obtain queue.")
fi

if ! [ -v ENVIRONMENT_PLANNER_APIXSEND ] ; then
    RESPONSE+=("environment: Specifies the API to perform e-mail send from a specific planner id.")
fi

if [ ${#RESPONSE[@]} -ne 0 ] ; then
    printf '%s\n' "${RESPONSE[@]}"
    runner
fi

unset RESPONSE

echo "Status ok!" > "$HEALTH"

export JQ
export CURL

trap runner SIGINT SIGQUIT SIGTERM

AUTHORIZATION=$($CURL -k -s -X POST -F "email=$ENVIRONMENT_PLANNER_USERNAME" -F "password=$ENVIRONMENT_PLANNER_PASSWORD" https://login.energia-europa.com/api/iam/user/login | $JQ -r .authorization)
RESPONSE=$($CURL -k -X POST -H "x-authorization: $AUTHORIZATION" "$ENVIRONMENT_PLANNER_APIQUEUE" | $JQ -rc .)
STATUS=$($JQ -rc .status <<< $RESPONSE)
[[ ${#STATUS} != true ]] && exit 0

readarray -t PLANNED < <($JQ -r .data[] <<< $RESPONSE)
for ID in "${PLANNED[@]}"; do
    echo "Call worker for planner $ID"
    $WORKER -i "$ID" &
    sleep 1
done

while sleep 8; do
    ps aux | grep "$WORKER" | grep -v grep > /dev/null
    if [[ $? -ne 0 ]]; then
        break
    fi
done

exit 0
