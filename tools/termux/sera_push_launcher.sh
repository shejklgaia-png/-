#!/data/data/com.termux/files/usr/bin/bash
# Installed as ~/sera_push.sh. The Python worker holds a cross-process lock.
set -u
exec python "$HOME/sera_push_safe.py"
