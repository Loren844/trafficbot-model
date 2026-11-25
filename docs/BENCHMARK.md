# Protocole de benchmark : trafficbot-model

Détection de panneaux et de feux tricolores sur le nœud caméra du TurtleBot3. Protocole en 8 étapes (cours *Edge AI Benchmarking*), écrit avant toute mesure.

| 1 Goal | 2 Workload | 3 Variables | 4 Metrics | 5 Setup | 6 Measure | 7 Analyze | 8 Report |
| --- | --- | --- | --- | --- | --- | --- | --- |
| exigences, axes des abaques | modèle, données | fixées / variées | définitions | matériel, environnement | runs, logs | statistiques | paquet reproductible |

**Question** : quelle configuration permet au robot de détecter panneaux et feux en temps réel ? Trois options : le Pi 4 embarqué, un Pi 5 + Hailo, ou l'image déportée vers un PC.

---

## Étape 1 : Goal

- Produire des abaques qui relient les choix de conception (machine, accélérateur, précision, résolution) aux résultats mesurés (latence, FPS, puissance, énergie, mAP, coût).
- Lecture à l'envers : partir de la spec ci-dessous et lister les configurations qui la respectent.
- Périmètre : toujours le pipeline complet, de la capture à la détection. Les temps par étage servent à expliquer les résultats et trouver le goulot, pas à remplacer la mesure de bout en bout.

| Exigence | Valeur | Dimension du benchmark |
| --- | --- | --- |
| Fonctionnelle | 5 panneaux, 6 classes : `stop`, `sens_interdit`, `interdit_gauche`, `interdit_droite`, `feu_rouge` (rouge ou orange), `feu_vert` ; mAP@0.5 ≥ 85 % ; rappel ≥ 95 % sur les classes critiques (`stop`, `sens_interdit`, `interdit_gauche`, `interdit_droite`, `feu_rouge`) ; confusion gauche/droite < 5 % ; confusion rouge/vert < 1 % ; objets dès 32 × 32 px à l'entrée du modèle (panneaux de 10 cm : ≈ 53 px à 0,5 m en 320) | modèle, résolution, dataset, qualité (mAP, rappel, matrice de confusion) |
| Optimisation | perte INT8 vs FP32 ≤ 1 point de mAP | précision, mAP mesurée sur la cible |
| Temps réel | capture → détection p95 ≤ 100 ms, p99 ≤ 150 ms ; ≥ 10 FPS soutenus 10 min ; < 5 % d'images perdues | latence pipeline (p50/p95/p99), FPS soutenus, images perdues |
| Énergie | dans le budget de l'alimentation USB-C de la carte (Pi 4 : 5 V / 3 A ; Pi 5 + Hailo : 5 V / 5 A) | puissance moyenne et pic, puissance idle, énergie par inférence |
| Thermique | pas de throttling après 10 min de charge | température, fréquence CPU, drapeaux de throttling |
| Mémoire | RSS ≤ 500 Mo | mémoire max |
| Coût | coût par configuration (carte + accélérateur + caméra) | coût unitaire |
| Intégration, robustesse | intégration dans trafficBot sans retouche ; 0 crash sur 10 min | couverture d'opérateurs, temps de chargement, stabilité sur un run long |

**Abaques visés** : latence p95 vs résolution par machine ; latence p95 x86 vs ARM à précision égale (FP32 / INT8) ; énergie par inférence vs mAP (front de Pareto) ; FPS soutenus vs puissance ; tableau exigences × configurations.

---

## Étapes 2 et 3 : Workload / Variables

| Fixées (contrôlées) | Variées (indépendantes) | Mesurées (dépendantes) |
| --- | --- | --- |
| Architecture YOLO nano, jeu de test figé, prétraitement (`preprocess.py`), batch 1, nombre de runs, refroidissement, image OS, température ambiante relevée | Machine (Dell XPS, MacBook M5, Pi 4, Pi 5), architecture CPU (x86 Intel / ARM), accélérateur (CPU / Hailo), précision (FP32 / INT8), runtime (ONNX Runtime, TFLite, HailoRT), résolution (320 / 640) | Latence par étage, FPS, puissance, énergie / inférence, mémoire, temps de chargement, mAP, température, couverture d'opérateurs Hailo |

- **Modèle** : YOLO nano, présent sur tous les runtimes et dans le Hailo Model Zoo. Entrée 320 × 320, variante 640. Chaque conversion, quantification et compilation est journalisée.
- **Données** : photos réelles des panneaux imprimés (caméra du robot) et captures Gazebo, annotées au format YOLO. Version figée, split avec graine, checksums SHA-256.
- **Augmentation** : pas de retournement horizontal, car il transformerait `interdit_gauche` en `interdit_droite` (ou alors il faut échanger les deux étiquettes) ; pas de variation de teinte forte, qui mélangerait les couleurs des feux.
- **Calibration INT8** : ≈ 200 images du train, disjointes du test.
- **Test sur cible** : sous-ensemble figé de 200 à 1000 images (taille à fixer), identique sur toutes les machines.
- **Rejeu** : la même séquence enregistrée (rosbag, ≥ 1000 images) est rejouée sur chaque machine pour les comparaisons.
- **Caméra live** : sur chaque Pi, un run avec la Camera Module 2 en direct valide l'exigence capture → détection (le Dell XPS et le MacBook M5 restent en rosbag).
- **Plan** : faire varier un facteur à la fois, puis croiser les facteurs pour construire les abaques.

| Machine | Architecture | Runtime | Précisions | Résolutions |
| --- | --- | --- | --- | --- |
| Dell XPS (Intel) | x86-64 | ONNX Runtime (CPU) | FP32, INT8 | 320, 640 |
| MacBook M5 | ARM64 (Apple Silicon) | ONNX Runtime (CPU) | FP32, INT8 | 320, 640 |
| Pi 4 (4 Go) | ARM64 (Cortex-A72) | TFLite (XNNPACK) | FP32, INT8 | 320, 640 |
| Pi 5 | ARM64 (Cortex-A76) | TFLite (XNNPACK) | FP32, INT8 | 320, 640 |
| Pi 5 + Hailo | ARM64 + NPU Hailo | HailoRT | INT8 | 320, 640 |

- **Comparaison x86 / ARM** : le Dell XPS et le MacBook M5 tournent avec le même runtime (ONNX Runtime CPU), les mêmes fichiers `.onnx`, la même précision et la même résolution. Seule l'architecture change. On compare la latence, et le gain INT8 vs FP32 sur chaque architecture (les instructions INT8 diffèrent : VNNI côté Intel, dotprod / i8mm côté ARM).
- Pour que la comparaison soit honnête, on fixe le nombre de threads, on note le modèle exact de CPU et on branche les deux portables sur secteur.

---

## Étape 4 : Metrics

| Métrique | Définition (horodatage de début → horodatage de fin) | Unité |
| --- | --- | --- |
| Latence d'inférence | tenseur d'entrée prêt → tenseur de sortie disponible | ms |
| Latence d'appel modèle | appel au runtime → résultats en mémoire hôte (copies PCIe du Hailo incluses) | ms |
| Latence pipeline | image capturée → détections après NMS ; p50 / p95 / p99 | ms |
| Temps par étage | capture, prétraitement, inférence, post-traitement (NMS) | ms |
| FPS soutenus | images traitées / durée d'observation en régime établi | FPS |
| Images perdues | images capturées non traitées / images capturées | % |
| Puissance | moyenne et pic sur une fenêtre en régime établi | W |
| Énergie / inférence | (∫₀ᵀ (P(t) − P_idle) dt) / N, pour N inférences en T | mJ |
| Qualité | mAP@0.5, rappel par classe, matrice de confusion, mesurés sur la cible ; perte vs FP32 | %, points |
| Mémoire, démarrage | RSS max ; temps du fichier modèle à la 1re inférence | Mo, s |
| Thermique | température SoC / Hailo, fréquence CPU, throttling | °C, MHz |

---

## Étape 5 : Setup

**Placement du wattmètre** : point B.

| Point | Ce qui est mesuré | Notre choix |
| --- | --- | --- |
| B : DC, en ligne (USB-C) | carte + caméra + Hailo + ventilateur | JT-TC66C entre l'alimentation et la carte |
| D : capteurs internes | rails et température, lus par logiciel | recoupement : `vcgencmd pmic_read_adc` (Pi 5), `hailortcli` (Hailo), `vcgencmd measure_temp` / `get_throttled` |

Le Dell XPS et le MacBook M5 ne sont pas mesurables avec le TC66C : on y compare seulement latence et précision, et le rapport le dit.

**Contrôle de l'environnement**

- **Thermique** : refroidissement fixe et noté par carte ; température et throttling journalisés pendant chaque run.
- **Horloges** : governor `performance` sur les Pi ; Dell XPS en mode d'alimentation « performances » et MacBook M5 sans mode économie d'énergie, tous deux sur secteur.
- **Isolation** : même image Raspberry Pi OS, services inutiles et interfaces non utilisées coupés, pas d'interface graphique.
- **Connexions** : même alimentation par carte (Pi 4 : 5 V / 3 A, Pi 5 : 5 V / 5 A), même câble, même port ; câble caméra avec adaptateur 22 broches sur le Pi 5 ; lien PCIe du Hailo relevé (`lspci -vv`).
- **Ambiance** : température de la salle relevée ; pas de mesure juste après la mise sous tension.
- **Ordre** : runs entrelacés entre configurations pour éviter la dérive.

---

## Étape 6 : Measure

**Latence**

- **Chronomètre** : `time.perf_counter_ns()`, appels synchrones, un horodatage par étage.
- **Warm-up** : les 50 premières inférences sont écartées.
- **Runs** : ≥ 1000 images par run, chaque échantillon est gardé (CSV).
- **Scénarios** : *single-stream* (débit maximal) et *cadencé caméra* (10 FPS imposés).

**Puissance et énergie**

- **Idle d'abord** : 60 s, avec Hailo et caméra branchés.
- **Régime établi** : ≥ 60 s de charge après le warm-up ; run long de 10 min pour les exigences temps réel et thermique.
- **Synchronisation** : horodatages de début et de fin de chaque run, pour les aligner sur la trace du TC66C.
- **Calcul** : énergie par inférence avec la puissance idle soustraite.

**Logs** : un dossier par run contenant la config YAML, les versions, le CSV des latences, la trace de puissance, la trace de température et de fréquence. Une commande par configuration : `bench.py --config <config>.yaml`.

---

## Étape 7 : Analyze

- **Mêmes données** : même jeu de calibration et même jeu de test sur chaque machine.
- **Précision sur la cible** : mAP recalculée sur les sorties du modèle compilé, pas sur celles du modèle PC.
- **Seuil de qualité** : on écarte des abaques toute configuration avec une perte > 1 point de mAP vs FP32 ou un rappel < 95 % sur une classe critique.
- **Répétitions** : 5 runs indépendants par configuration.
- **Résumés** : médiane + IQR ; percentiles p50 / p95 / p99 pour la latence.
- **Figures** : CDF de latence, box plots, latence empilée par étage, front de Pareto latence × énergie × mAP, tableau exigences × configurations.

---

## Étape 8 : Report

- **Paquet** : code, configs, logs bruts et scripts lançables en une commande (`train`, `export`, `bench`, `analyze`).
- **Versions** : OS, noyau, Python, ONNX Runtime, TFLite, HailoRT, Dataflow Compiler, fichiers modèle avec checksums (release GitHub).
- **Notes matériel** : refroidissement, alimentation, câbles, position du TC66C, fréquence d'échantillonnage.
- **Erreurs à éviter** : comparer des précisions ou résolutions différentes sans le dire ; ne donner que la moyenne ou le meilleur run ; ignorer la puissance idle, le throttling ou le repli CPU du Hailo.

---

## Synthèse

| Étape | Choix pour « détection de panneaux et de feux sur le TurtleBot3 » |
| --- | --- |
| 1 Goal | p95 ≤ 100 ms capture → détection, ≥ 10 FPS soutenus, mAP@0.5 ≥ 85 %, rappel ≥ 95 % sur les classes critiques, perte INT8 ≤ 1 point, RSS ≤ 500 Mo, sans throttling. Abaques de latence, puissance et mAP par machine |
| 2 Workload | YOLO nano INT8/FP32 en 320 (variante 640), jeu de test figé de panneaux imprimés réels + Gazebo ; séquence enregistrée rejouée pour les comparaisons, caméra live sur les Pi pour valider capture → détection |
| 3 Variables | Fixées : modèle, jeu de test, batch 1. Variées : machine (Dell XPS x86, MacBook M5 ARM, Pi 4, Pi 5, Pi 5 + Hailo), architecture x86 / ARM, précision, runtime, résolution 320 ou 640 |
| 4 Metrics | Latence pipeline p50/p95/p99, temps par étage, FPS soutenus, images perdues, puissance, mJ par inférence, mAP sur cible, RSS, température |
| 5 Setup | TC66C en point B, même alimentation et même refroidissement, governor `performance`, lien PCIe relevé, idle journalisé |
| 6 Measure | Warm-up, ≥ 1000 images par run, 10 min par configuration, single-stream et cadencé 10 FPS, horodatages par étage, puissance journalisée en parallèle |
| 7 Analyze | 5 répétitions, médiane + IQR, CDF de latence, perte vs FP32, front de Pareto énergie × mAP |
| 8 Report | Dépôt avec scripts, versions, logs bruts, README et abaques |
