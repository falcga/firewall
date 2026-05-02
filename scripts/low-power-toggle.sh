#!/usr/bin/env bash
# Опциональный режим powerbank — не гарантирован на всех ядрах/драйверах Wi‑Fi.
set -euo pipefail

mode="${1:-status}"
wlan="${LOW_POWER_WLAN:-wlan0}"

case "$mode" in
status)
  if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    echo "scaling_governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
  fi
  if command -v iw >/dev/null 2>&1; then iw dev "$wlan" info 2>/dev/null || true; fi
  ;;
on)
  for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [[ -w "$g" ]] && echo powersave >"$g" || true
  done
  if command -v vcgencmd >/dev/null 2>&1; then vcgencmd display_power 0 >/dev/null 2>&1 || true; fi
  if command -v iw >/dev/null 2>&1; then iw dev "$wlan" set power_save on >/dev/null 2>&1 || true; fi
  echo low-power-on
  ;;
off)
  for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [[ -w "$g" ]] && echo ondemand >"$g" 2>/dev/null || echo performance >"$g" || true
  done
  if command -v vcgencmd >/dev/null 2>&1; then vcgencmd display_power 1 >/dev/null 2>&1 || true; fi
  if command -v iw >/dev/null 2>&1; then iw dev "$wlan" set power_save off >/dev/null 2>&1 || true; fi
  echo low-power-off
  ;;
*)
  echo "usage: low-power-toggle.sh on|off|status" >&2
  exit 2
  ;;
esac
