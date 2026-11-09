#!/bin/sh
# usage: setup_emu.sh <serial>  — install the debug app, copy the phone's app data and catalogs, launch it.
set -e
S=$1
cd /c/Users/ahnlee123/Desktop/jidoapp
export MSYS_NO_PATHCONV=1
P=com.ahnlee.jidoapp
adb -s $S install -r -g build/app/outputs/flutter-apk/app-debug.apk
adb -s $S shell am force-stop $P
adb -s $S push build/overflow_audit/appdata.tar /data/local/tmp/appdata.tar
adb -s $S shell "run-as $P sh -c 'tar xf /data/local/tmp/appdata.tar -C . 2>/dev/null; mkdir -p files/l10n'"
for f in build/l10n/*.json; do
  b=$(basename $f)
  adb -s $S push $f /data/local/tmp/$b >/dev/null
  adb -s $S shell "run-as $P cp /data/local/tmp/$b files/l10n/$b; rm /data/local/tmp/$b"
done
adb -s $S shell rm /data/local/tmp/appdata.tar
adb -s $S shell monkey -p $P -c android.intent.category.LAUNCHER 1 >/dev/null
echo "$S ready"
