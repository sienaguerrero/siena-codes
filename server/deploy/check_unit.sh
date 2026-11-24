#!/bin/sh
installed=${INSTALLED_UNIT:-$(systemctl show -p FragmentPath --value guestbook 2>/dev/null)}
committed=${COMMITTED_UNIT:-$(dirname "$0")/guestbook.service}

if [ -z "$installed" ] || [ ! -r "$installed" ] || [ ! -r "$committed" ]; then
  echo unknown
  exit 2
fi
if ! cmp -s "$installed" "$committed"; then
  echo differs
  exit 1
fi
if [ "${NEED_DAEMON_RELOAD:-$(systemctl show -p NeedDaemonReload --value guestbook 2>/dev/null)}" != no ]; then
  echo reload
  exit 1
fi
echo current
