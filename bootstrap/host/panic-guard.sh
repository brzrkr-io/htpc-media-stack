#!/bin/sh
# panic-guard: keep an oops from ever rebooting this box.
# kubelet (k3s) hardcodes kernel.panic_on_oops=1 and kernel.panic=10 every time
# it starts, and kdump-config used to do the same. This loop re-zeroes them
# within 2s of anything re-arming them, and logs when it had to.
set -u
while :; do
    for knob in panic_on_oops panic hung_task_panic softlockup_panic; do
        f="/proc/sys/kernel/$knob"
        [ -e "$f" ] || continue
        v=$(cat "$f")
        if [ "$v" != "0" ]; then
            echo 0 > "$f"
            echo "panic-guard: kernel.$knob was $v, re-zeroed (something re-armed it)"
        fi
    done
    sleep 2
done
