#!/usr/bin/env bash
# Prépare un Raspberry Pi (4 ou 5) pour le benchmark.
#   1. governor "performance" permanent (service systemd)
#   2. arrêt des services inutiles et démarrage sans interface graphique
#   3. environnement Python dans .venv (numpy, OpenCV, ONNX Runtime, LiteRT)
# Usage : sudo ./scripts/setup_pi.sh [--pcie-gen3]
#   --pcie-gen3 : Pi 5 uniquement, passe le lien PCIe du Hailo en Gen3 (redémarrage nécessaire).
# Le script peut être relancé sans risque.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "À lancer avec sudo." >&2
  exit 1
fi

USER_NAME="${SUDO_USER:-$(logname)}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PCIE_GEN3=0
[ "${1:-}" = "--pcie-gen3" ] && PCIE_GEN3=1

echo "== 1. Governor performance"
cat > /etc/systemd/system/cpu-performance.service <<'EOF'
[Unit]
Description=Governor CPU performance pour le benchmark

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$g"; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now cpu-performance.service
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c

echo "== 2. Services inutiles"
for s in bluetooth hciuart cups cups-browsed avahi-daemon ModemManager triggerhappy; do
  if systemctl list-unit-files "$s.service" 2>/dev/null | grep -q "^$s.service"; then
    systemctl disable --now "$s.service" >/dev/null 2>&1 && echo "désactivé : $s"
  fi
done
systemctl set-default multi-user.target >/dev/null
echo "démarrage par défaut : $(systemctl get-default)"

echo "== 3. Environnement Python"
apt-get update -qq
apt-get install -y -qq python3-venv python3-picamera2 >/dev/null
sudo -u "$USER_NAME" python3 -m venv --system-site-packages "$REPO_DIR/.venv"
sudo -u "$USER_NAME" "$REPO_DIR/.venv/bin/pip" install -q --upgrade pip
sudo -u "$USER_NAME" "$REPO_DIR/.venv/bin/pip" install -q -r "$REPO_DIR/scripts/requirements-pi.txt"

if [ "$PCIE_GEN3" -eq 1 ]; then
  echo "== 4. PCIe Gen3 (Pi 5)"
  CFG=/boot/firmware/config.txt
  if ! grep -q '^dtparam=pciex1_gen=3' "$CFG"; then
    printf '\n# Lien PCIe du Hailo en Gen3 (benchmark)\ndtparam=pciex1\ndtparam=pciex1_gen=3\n' >> "$CFG"
    echo "ajouté à $CFG, redémarrer pour l'appliquer"
  else
    echo "déjà présent dans $CFG"
  fi
fi

echo "Terminé. Vérifier avec : ./scripts/versions.sh"
