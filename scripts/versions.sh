#!/usr/bin/env bash
# Affiche la configuration logicielle et matérielle d'une machine de benchmark.
# Usage : ./scripts/versions.sh [chemin/vers/.venv] > results/setup_<machine>.txt
# Fonctionne sur Raspberry Pi, Linux x86 et macOS (les sections absentes sont ignorées).

VENV="${1:-.venv}"
PY="python3"
[ -x "$VENV/bin/python" ] && PY="$VENV/bin/python"

have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n## %s\n' "$1"; }

echo "# Configuration de $(hostname)"
echo "date: $(date -Iseconds 2>/dev/null || date)"

section "Système"
if [ -r /proc/device-tree/model ]; then
  echo "modèle: $(tr -d '\0' < /proc/device-tree/model)"
fi
if [ -r /etc/os-release ]; then
  . /etc/os-release && echo "os: $PRETTY_NAME"
elif have sw_vers; then
  echo "os: macOS $(sw_vers -productVersion)"
fi
echo "noyau: $(uname -r)"
echo "architecture: $(uname -m)"
if have lscpu; then
  lscpu | grep -E '^(Model name|CPU\(s\)):'
elif have sysctl; then
  echo "cpu: $(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
  echo "coeurs: $(sysctl -n hw.ncpu)"
fi
if [ -r /proc/cpuinfo ]; then
  echo "instructions INT8: $(grep -o -w -E 'avx512_vnni|avx_vnni|asimddp|i8mm' /proc/cpuinfo | sort -u | tr '\n' ' ')"
fi
if have free; then free -m | sed -n '1,2p'; fi

section "Fréquence CPU"
if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
  for c in /sys/devices/system/cpu/cpu[0-9]*; do
    echo "$(basename "$c"): governor=$(cat "$c/cpufreq/scaling_governor") cur=$(( $(cat "$c/cpufreq/scaling_cur_freq") / 1000 )) MHz max=$(( $(cat "$c/cpufreq/scaling_max_freq") / 1000 )) MHz"
  done
else
  echo "non disponible sur cette machine"
fi

if have vcgencmd; then
  section "Raspberry Pi (vcgencmd)"
  echo "température: $(vcgencmd measure_temp)"
  echo "throttling: $(vcgencmd get_throttled)   (0x0 = aucun)"
  echo "arm: $(vcgencmd measure_clock arm)"
  echo "firmware: $(vcgencmd version | tr '\n' ' ')"
  if vcgencmd pmic_read_adc >/dev/null 2>&1; then
    echo "pmic (Pi 5) :"
    vcgencmd pmic_read_adc | sed 's/^/  /'
  fi
fi

section "Caméra"
if have rpicam-hello; then
  rpicam-hello --list-cameras 2>&1 | sed 's/^/  /'
else
  echo "rpicam-hello absent"
fi

section "Hailo"
if have lspci; then
  dev=$(lspci -d 1e60: 2>/dev/null | awk '{print $1}' | head -1)
  if [ -n "$dev" ]; then
    lspci -s "$dev"
    sudo -n lspci -vv -s "$dev" 2>/dev/null | grep -E 'LnkCap:|LnkSta:' | sed 's/^\s*/  /' \
      || echo "  (lancer avec sudo pour lire la vitesse du lien PCIe)"
    echo "  rappel : 5GT/s = PCIe Gen2, 8GT/s = PCIe Gen3"
  else
    echo "aucun périphérique Hailo sur le bus PCIe"
  fi
fi
if have hailortcli; then
  echo "hailortcli: $(hailortcli --version 2>&1 | head -1)"
  hailortcli fw-control identify 2>&1 | sed 's/^/  /'
fi
if [ -r /boot/firmware/config.txt ]; then
  echo "config.txt (pcie): $(grep -E '^dtparam=pciex1' /boot/firmware/config.txt | tr '\n' ' ')"
fi

section "Python et runtimes ($PY)"
echo "python: $("$PY" -c 'import platform; print(platform.python_version())')"
echo "taille de page mémoire: $(getconf PAGESIZE 2>/dev/null || echo inconnue) octets"
# Chaque module est importé dans un processus séparé : un module qui plante
# (Bus error, Segmentation fault) est signalé sans arrêter le reste du relevé.
for spec in numpy:numpy cv2:opencv onnxruntime:onnxruntime ai_edge_litert:ai-edge-litert hailo_platform:hailort picamera2:picamera2; do
  mod="${spec%%:*}"; name="${spec##*:}"
  out=$("$PY" -c "
import importlib
m = importlib.import_module('$mod')
v = getattr(m, '__version__', None)
if v is None:
    try:
        from importlib.metadata import version
        v = version('$name')
    except Exception:
        v = 'installé'
print(v)
" 2>/dev/null)
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "$name: $out"
  elif [ $rc -eq 1 ]; then
    echo "$name: absent"
  else
    echo "$name: PLANTAGE à l'import (code $rc, 135 = Bus error, 139 = Segmentation fault)"
  fi
done
"$PY" -c "import onnxruntime as ort; print('onnxruntime providers:', ', '.join(ort.get_available_providers()))" 2>/dev/null || true
