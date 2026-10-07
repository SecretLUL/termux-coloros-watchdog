#!/data/data/com.termux/files/usr/bin/sh
# diagnose.sh: find out why Android killed Termux (read-only, changes nothing).
#
# Needs a working "adb" connection to the phone itself (e.g. wireless
# debugging + "adb connect 127.0.0.1:<port>" from inside Termux).
# Usage: ./diagnose.sh [package ...]   (default: com.termux com.termux.api com.termux.boot)

[ $# -gt 0 ] || set -- com.termux com.termux.api com.termux.boot

adb get-state >/dev/null 2>&1 || { echo "adb is not connected" >&2; exit 1; }

echo "== Device"
adb shell 'echo "$(getprop ro.product.manufacturer) $(getprop ro.product.model), Android $(getprop ro.build.version.release), $(getprop ro.build.display.id)"; uptime'

echo
echo "== Phantom process killer (should be: false / 2147483647)"
adb shell 'echo "settings_enable_monitor_phantom_procs = $(settings get global settings_enable_monitor_phantom_procs)"; echo "max_phantom_processes = $(device_config get activity_manager max_phantom_processes)"'

for p in "$@"; do
	echo
	echo "== $p"
	adb shell "
		echo \"force-stopped:   \$(dumpsys package $p | grep -o 'stopped=[a-z]*' | head -1)\"
		echo \"standby bucket:  \$(am get-standby-bucket $p)  (5 = exempted, 10 = active)\"
		echo \"battery whitelist: \$(dumpsys deviceidle whitelist | grep -q ,$p, && echo yes || echo NO)\"
		echo \"appops:          \$(cmd appops get $p RUN_ANY_IN_BACKGROUND)\"
		echo 'last process exits (newest first):'
		dumpsys activity exit-info $p | grep -E 'timestamp=|reason=|description=' | sed 's/^ */  /' | head -24
	"
done

echo
echo "== Termux:API jobs"
adb shell 'dumpsys jobscheduler | grep -A8 "JOB #.*com.termux.api" | grep -E "JOB #|PERIODIC|PERSISTED|script_path"'
