# Installation des machines de benchmark

Procédure de mise en place des Raspberry Pi pour l'étape 5 (Setup) du [protocole](BENCHMARK.md). Le relevé des versions de chaque machine se fait avec `scripts/versions.sh`.

## Matériel

| Machine | Refroidissement | Alimentation | Caméra | Accélérateur |
| --- | --- | --- | --- | --- |
| Raspberry Pi 4 (4 Go) | dissipateurs métalliques passifs | USB-C 5 V / 3 A | Camera Module 2 | — |
| Raspberry Pi 5 | ventilateur | USB-C 5 V / 5 A | Camera Module 2 (adaptateur 22 broches) | Hailo sur PCIe, dissipateur métallique passif |
| PC x86 (Dell XPS) | d'origine | secteur, mode « performances » | — | — |
| MacBook M5 | d'origine | secteur, sans mode économie d'énergie | — | — |

Le refroidissement ne change pas pendant toute la campagne. Le JT-TC66C se place entre l'alimentation et la carte (point B du cours).

## Raspberry Pi

Les deux Pi utilisent la même image Raspberry Pi OS 64 bits, sans interface graphique. La caméra et les paquets Hailo (Pi 5) sont déjà installés.

1. Cloner le dépôt sur le Pi :

   ```bash
   git clone https://github.com/Loren844/trafficbot-model.git && cd trafficbot-model
   ```

2. Lancer la préparation :

   ```bash
   sudo ./scripts/setup_pi.sh
   ```

   Le script :
   - fixe le governor CPU à `performance` à chaque démarrage (service `cpu-performance`) ;
   - désactive Bluetooth, impression, Avahi, ModemManager et triggerhappy, et démarre en mode console ;
   - crée `.venv` avec numpy, OpenCV, ONNX Runtime et LiteRT (`ai-edge-litert`). Le venv voit les paquets système, donc `picamera2` et le module Python de HailoRT restent accessibles.

3. Redémarrer, puis relever la configuration :

   ```bash
   mkdir -p results && ./scripts/versions.sh > results/setup_$(hostname).txt
   ```

   Pour lire la vitesse du lien PCIe du Hailo, lancer le script avec `sudo`.

### Lien PCIe du Hailo (Pi 5)

Le Hailo est relié au Pi 5 par un lien PCIe à une voie. Par défaut, ce lien tourne en Gen2 (5 GT/s). Il peut passer en Gen3 (8 GT/s), environ deux fois plus de débit, ce qui réduit le temps de copie des images vers le Hailo. Raspberry Pi ne certifie pas le Gen3, mais il est largement utilisé avec le Hailo.

- Vitesse actuelle : ligne `LnkSta` de `sudo ./scripts/versions.sh` (`5GT/s` = Gen2, `8GT/s` = Gen3).
- Passage en Gen3 : `sudo ./scripts/setup_pi.sh --pcie-gen3`, puis redémarrer.

Le mode choisi est une variable fixée du protocole : il est noté et ne change plus pendant la campagne.

## PC x86 et MacBook

```bash
python3 -m venv .venv && source .venv/bin/activate
```

```bash
pip install numpy onnxruntime ultralytics
```

```bash
mkdir -p results && ./scripts/versions.sh > results/setup_$(hostname).txt
```

Le Dataflow Compiler de Hailo (compilation `.hef`) s'installe sur le PC x86 sous Linux.

## Relevés

Une fois les scripts lancés, les sorties sont rangées dans `results/setup_<machine>.txt` et résumées ici.

| Machine | OS | Noyau | Python | ONNX Runtime | LiteRT | HailoRT | Lien PCIe |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Pi 4 | | | | | | — | — |
| Pi 5 | | | | | | | |
| PC x86 | | | | | — | — | — |
| MacBook M5 | | | | | — | — | — |
