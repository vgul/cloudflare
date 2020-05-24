#!/bin/bash

set -u

CACHE=0 # for debug
CONF_FILE='/etc/cloudflare'
CACHE_DIR='/var/cache/local/cloudflare/'
LOG_DIR='/var/log/local/'
LOG_FILE="${LOG_DIR}/cloudflare.log"

test -d $CACHE_DIR || mkdir -vp $CACHE_DIR

if [ -f $CONF_FILE ]; then
    . $CONF_FILE
else
    echo "No '${CONF_FILE}' found. Exiting"
    exit 1
fi


function log {
    local STR="${1:-***}"
    echo "$(date +'%F %T') $STR"
}

function usage {
  cat << EOC 

  cloudflare.sh - manage DNS for cloudflare

  How to run

  cloudflare.sh [OPTIONS]  [DOMAIN1:IP1  [DOMAIN2:IP2 .. [DOMAINn:IPn] ] ]
    --[no-]dry-run - use cached data
    --help         - this help
        
  '${CONF_FILE}' should contain variables

      Zone_ID='48...'
      Email='ben.laden@gmail.com'
      Your_API_Key='...'
EOC

}

TARGET=() ## Element looks like: 'example.com:127.0.0.1'

DRY_RUN=
NO_DRY_RUN=
while [ $# -gt 0 ]; do
    case "$1" in
  
       --help|-h|-\?)
            usage
            exit 0
            ;;
       --no-dry-run)
            NO_DRY_RUN=1
            shift
            ;;
       --dry-run)
            DRY_RUN=1
            shift
            ;;
        --)
            # Rest of command line arguments are non option arguments
            shift # Discard separator from list of arguments
            continue
            ;;

        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 2
            ;;

        *)
            TARGET+=("$1")
            shift
    esac
done

((!DRY_RUN)) && ((!NO_DRY_RUN)) &&  DRY_RUN=1
((DRY_RUN)) && ((NO_DRY_RUN)) && {
    log "Either or --dry-run or --no-dry-run"
    exit 0
}


RAW_DNS_RECORDS_FILE="${CACHE_DIR}dns-records.json"

(( 1 )) && {
    if ((!CACHE)); then
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${Zone_ID}/dns_records" \
             -H "X-Auth-Email: ${Email}" \
             -H "X-Auth-Key: ${Your_API_Key}" \
             -H "Content-Type: application/json" > $RAW_DNS_RECORDS_FILE
    fi

    RAW_DNS_RECORDS=$(cat $RAW_DNS_RECORDS_FILE)
}

log "Start."

if [ -z "${NO_DRY_RUN}" ]; then
    log 'No --no-dry-run specified. No ANY UPDATES'
else
    log '--no-dry-run specified. Real mode'
fi

for E in "${TARGET[@]}"; do

    HOST=${E%%:*}
    IP=${E##*:}
    DATA=$(echo "${RAW_DNS_RECORDS}" | \
        jq -r " .result | .[] | select ( .name == \"${HOST}\" 
            and .type == \"A\" ) | \"\(.content) \(.id)\"  " )
    #echo Host $HOST Ip $IP :     $DATA
    OLD_IP=${DATA%% *}


    printf -v MESG "Host: %-25s; Desired: %14s." "'${HOST}'" "'${IP}'"
    if [ -n "${DATA}" ]; then
        if [ "${IP}" != "${OLD_IP}" ]; then
            MESG="${MESG} Got IP are mismatch [$OLD_IP]"
            log "$MESG"
        else
            MESG="${MESG} IP are equil."
            log "$MESG"
            continue
        fi
    else
        MESG="${MESG} No clodflare 'placeholders' for this record."
        log "$MESG"
        continue
    fi


    [ -z "${NO_DRY_RUN}" ] && continue
    RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${Zone_ID}/dns_records/1c5e3833784e69ab22fe6808572bd67c" \
         -H "X-Auth-Email: ${Email}" \
         -H "X-Auth-Key: ${Your_API_Key}" \
         -H "Content-Type: application/json" \
         --data '{"type":"A","name":"'${HOST}'","content":"'${IP}'","ttl":120,"proxied":false}' \
         | tee "${CACHE_DIR}/${HOST}-update.json" | jq -r ' .success' )
    log "  Update status: $RESULT"
done

log "Finish."


