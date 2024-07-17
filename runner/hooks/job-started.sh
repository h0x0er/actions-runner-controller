#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=runner/logger.sh
source logger.sh

log.debug "Running ARC Job Started Hooks"

hook_dir="/etc/arc/hooks/job-started.d"

for hook in /etc/arc/hooks/job-started.d/*; do
  log.debug "Running hook: $hook"
  full_hook="$hook_dir/$hook"
  chmod +x $full_hook

  exec $full_hook "$@"
done
