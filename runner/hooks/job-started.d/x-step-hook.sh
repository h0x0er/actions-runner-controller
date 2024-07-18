#!/usr/bin/env bash
set -u

source logger.sh

function step-log(){
    log.debug "[StepSecurity] $1"
}

step-log "Failing job"
exit 1
