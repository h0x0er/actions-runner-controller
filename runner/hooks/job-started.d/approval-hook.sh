#!/usr/bin/env bash
set -u

__log() {
  local color instant level

  color=${1:?missing required <color> argument}
  shift

  level=${FUNCNAME[1]} # `main` if called from top-level
  level=${level#log.} # substring after `log.`
  level=${level^^} # UPPERCASE

  if [[ ! -v "LOG_${level}_DISABLED" ]]; then
    instant=$(date '+%F %T.%-3N' 2>/dev/null || :)

    # https://no-color.org/
    if [[ -v NO_COLOR ]]; then
      printf -- '%s  %s --- %s\n' "$instant" "$level" "$*" 1>&2 || :
    else
      printf -- '\033[0;%dm%s  %s --- %s\033[0m\n' "$color" "$instant" "$level" "$*" 1>&2 || :
    fi
  fi
}

log.debug   () { __log 37 "$@"; } # white
log.notice  () { __log 34 "$@"; } # blue
log.warning () { __log 33 "$@"; } # yellow
log.error   () { __log 31 "$@"; } # red
log.success () { __log 32 "$@"; } # green

step-log-debug () { log.debug "[StepSecurity] $1"; }
step-log-error () { log.error "[StepSecurity] $1"; }
step-log-success  () { log.success "[StepSecurity] $1"; }
step-log-warning  () { log.warning "[StepSecurity] $1"; }
step-log-notice  () { log.notice "[StepSecurity] $1"; }



GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-}
GITHUB_RUN_ID=${GITHUB_RUN_ID:-}
GITHUB_COMMIT_SHA=""

ERROR_COUNT=0
ERROR_RESP=""
APPROVAL_SHOWED=0

CONSOLE_BASE="https://int1.stepsecurity.io"
API_BASE="https://int.api.stepsecurity.io/v1"

SHOULD_CI_RUN="$API_BASE/github/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/should-ci-run"


function handleResponse(){
    local resp=${1}
    local lastStatus=${2}

    local err
    echo "$resp" | grep -q "error"  > /dev/null
    err=$?
    if [[ $err -eq 0 ]] || [[ $lastStatus -ne 0 ]]; then
        # step-log-error "error response received: $resp"
        ERROR_COUNT=$((ERROR_COUNT += 1))
        ERROR_RESP="$resp"
    fi
    
    if [[ $ERROR_COUNT -eq 4 ]]; then
        step-log-error "error occured: $ERROR_RESP"
        exit 1
    fi


    local hasCommitSha
    echo "$resp" | grep -q "commit_sha" > /dev/null
    hasCommitSha=$?

    if [[ $GITHUB_COMMIT_SHA == "" ]] && [[ $hasCommitSha -eq 0 ]]; then
        GITHUB_COMMIT_SHA=$(echo "$resp" | jq -r '.commit_sha')
    fi

    local isApproved
    echo "$resp" | grep -q "approved_by" > /dev/null
    isApproved=$?
    if [[ $isApproved -eq 0 ]]; then

        approver=$(echo "$resp" | jq -r '.approved_by')
        step-log-success "Approved by: $approver"
        step-log-notice "Continuing job"
        exit 0

    fi

}

function printApprovalInfo(){

    if [[ $GITHUB_COMMIT_SHA != "" ]] && [[ $APPROVAL_SHOWED -eq 0 ]]; then

        step-log-notice "Waiting to be approved.."

        step-log-notice "Approval URL: $CONSOLE_BASE/github/$GITHUB_REPOSITORY/commits/$GITHUB_COMMIT_SHA/approve-ci-run"

        # step-log-debug "$SHOULD_CI_RUN"

        APPROVAL_SHOWED=1

    fi
}


function main(){

    local resp
    local counter
    local maxWait

    counter=0
    maxWait=60 # wait for 5 minutes
    

    while [[ $counter -ne $maxWait ]]; do
        # step-log-debug "[$counter] waiting.."

        resp=$(curl -XGET -s "${SHOULD_CI_RUN}")
        handleResponse "${resp}" $?

        printApprovalInfo

        counter=$((counter += 1))
        sleep 5

    done

    step-log-warning "No-one approved run, waited for maximum time"
    step-log-warning "Failing job"

    exit 1

}


main









