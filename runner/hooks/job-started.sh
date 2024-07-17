#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=runner/logger.sh
source logger.sh

log.debug "Running ARC Job Started Hooks"

hook_dir="/etc/arc/hooks/job-started.d"

for hook in /etc/arc/hooks/job-started.d/*; do
  log.debug "Running hook: $hook"
  chmod +x $hook
  
  exec $hook "$@"
done
