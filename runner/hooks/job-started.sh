#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=runner/logger.sh
source logger.sh

log.debug "Running ARC Job Started Hooks"

# log.debug "making startup-hooks executable"
sudo chmod ugo+x /etc/arc/hooks/job-started.d/*

# log.debug "$(ls -lah /etc/arc/hooks/job-started.d)"

for hook in /etc/arc/hooks/job-started.d/*; do
  log.debug "Running hook: $hook"  
  "$hook" "$@"
done
