#!/usr/bin/env bash
# Runs a real three-player co-op game: one host and two guests, as separate processes on this
# computer. Usage: tests/network/run_coop_live.sh /path/to/Godot_console.exe [port]
set -u
godot="$1"
port="${2:-9190}"
logs="$(mktemp -d)"

for role in host guest2 guest3; do
	timeout 150 "$godot" --headless --path . --script res://tests/network/coop_live_test.gd -- --role=$role --port=$port \
		</dev/null >"$logs/$role.log" 2>&1 &
	pids+=($!)
done

failed=0
for pid in "${pids[@]}"; do
	wait "$pid" || failed=1
done

for role in host guest2 guest3; do
	grep -E "FAIL|failures|SCRIPT ERROR|at: |WORLD|SNAPSHOT|VOLLEY" "$logs/$role.log" | grep -vE "object.cpp|resource.cpp|string_name" | head -30
done

worlds="$(cat "$logs"/*.log | grep -c '^WORLD')"
distinct="$(cat "$logs"/*.log | grep '^WORLD' | sort -u | wc -l)"
if [ "$worlds" -ne 3 ] || [ "$distinct" -ne 1 ]; then
	echo "FAIL: the three players must generate the same map ($worlds reports, $distinct different)"
	failed=1
fi
[ "$failed" -eq 0 ] && echo "PASS: three-player co-op over a real connection" || echo "FAILED, logs in $logs"
exit "$failed"
