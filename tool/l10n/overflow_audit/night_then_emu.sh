#!/bin/sh
# usage: night_then_emu.sh <HH:MM switch time>
# Runs the audit on the phone until the switch time, then stops it and
# continues on emulator-5558 (the two can't run together on this PC).
cd /c/Users/ahnlee123/Desktop/jidoapp
export PATH="$LOCALAPPDATA/Android/Sdk/platform-tools:$PATH"
D=tool/l10n/overflow_audit
END=$(date -d "tomorrow $1" +%s)
[ $(( END - $(date +%s) )) -gt 86400 ] && END=$(date -d "$1" +%s)

left() { echo $(( END - $(date +%s) )); }

run() { # device log tier-args...
  dev=$1; log=$2; shift 2
  echo "=== $* on $dev start $(date)" >> $log
  AUDIT_DEVICE=$dev "$@" >> $log 2>&1
  echo "=== $* on $dev end $(date) exit=$?" >> $log
}

P=192.168.0.6:5555
L=$D/run_phone.log
adb connect $P >/dev/null
if [ $(left) -gt 60 ]; then
  run $P $L timeout --signal=KILL $(left) python -I $D/drive.py --tier 1 --retry
fi
if [ $(left) -gt 60 ]; then
  run $P $L timeout --signal=KILL $(left) python -I $D/drive.py --tier 2 --all
fi
echo "=== switch to emulator $(date)" >> $L

E=emulator-5558
L=$D/run_emu5558.log
run $E $L python -I $D/drive.py --tier 1 --retry
run $E $L python -I $D/drive.py --tier 2 --all
echo "=== all done $(date)" >> $L
