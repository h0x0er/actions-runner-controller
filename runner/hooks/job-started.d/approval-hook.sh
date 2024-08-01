#!/usr/bin/env bash
set -u
source logger.sh

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

api_base="https://int.api.stepsecurity.io/v1"
should_ci_run="$api_base/github/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/should-ci-run"


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

        step-log-notice "Approval URL: https://int1.stepsecurity.io/github/$GITHUB_REPOSITORY/commits/$GITHUB_COMMIT_SHA/approve-ci-run"

        # step-log-debug "$should_ci_run"

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

        resp=$(curl -XGET -s "${should_ci_run}")
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









