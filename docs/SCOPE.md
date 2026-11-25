# Périmètre — trafficbot-model (Edge AI)

Ce repo livre un détecteur de panneaux et de feux optimisé pour l'embarqué, et un benchmark reproductible qui dit sur quel matériel et avec quelle optimisation il tient la contrainte temps réel du robot.

Le modèle est utilisé par le repo jumeau [`trafficBot`](https://github.com/MatveiMKS/trafficBot) (cours Systèmes intelligents autonomes) : un TurtleBot3 qui suit un circuit miniature et respecte stop, sens interdit, interdictions de tourner à gauche et à droite, et feu tricolore. Le cours Edge AI demande explicitement cet alignement entre les deux projets.

## Matériel

| Rôle | Matériel |
| --- | --- |
| Cible principale (embarquée sur le robot) | Raspberry Pi 4 du TurtleBot3 + Pi Camera |
| Banc de benchmark | Raspberry Pi 5 + accélérateur Hailo, Raspberry Pi 4 (4 Go), Pi Camera |
| Références de comparaison | Dell XPS (x86, Linux), MacBook M5 (ARM, Apple Silicon) |
| Mesure de consommation | wattmètre USB-C JT-TC66C, placé entre l'alimentation et la carte (point B du cours) |

## Inclus (obligatoire)

1. **Application et exigences** (étape 1 du protocole, détail dans [BENCHMARK.md](BENCHMARK.md)) :
   - 6 classes : `stop`, `sens_interdit`, `interdit_gauche`, `interdit_droite`, `feu_rouge` (rouge ou orange), `feu_vert` ;
   - mAP@0.5 ≥ 85 %, rappel ≥ 95 % sur les classes critiques, confusion gauche / droite < 5 %, confusion rouge / vert < 1 % ;
   - objets dès 32 × 32 px à l'entrée du modèle ;
   - latence capture → détection p95 ≤ 100 ms et p99 ≤ 150 ms, au moins 10 FPS soutenus pendant 10 min ;
   - perte de précision INT8 vs FP32 ≤ 1 point ;
   - RSS ≤ 500 Mo, pas de throttling après 10 min de charge.
2. **Dataset** : images réelles des panneaux imprimés prises avec la caméra du robot, plus des captures Gazebo, annotées en boîtes (format YOLO). Version figée, split train/val/test avec graine, checksums, jeu de calibration distinct du jeu de test.
3. **Modèle** : YOLO nano, disponible sur tous les runtimes et dans le Hailo Model Zoo, entrée 320×320, variante 640.
4. **Optimisations** : export ONNX et TFLite en FP32 et INT8 (quantification avec calibration), compilation pour le Hailo (Dataflow Compiler → `.hef`, INT8), variante de résolution 320 / 640.
5. **Benchmark sur 5 configurations** : Dell XPS (x86), MacBook M5 (ARM), Raspberry Pi 4 (4 Go), Raspberry Pi 5 sur CPU, Raspberry Pi 5 + Hailo. L'étage capteur est mesuré avec la Pi Camera sur les deux Pi.
6. **Protocole écrit avant les mesures**, selon les 8 étapes du cours (objectif, workload, variables, métriques, setup, mesure, analyse, rapport).

## Protocole de benchmark (résumé)

| Étape | Choix |
| --- | --- |
| Variables fixées | modèle, dataset de test, batch 1, nombre de runs, refroidissement |
| Variables étudiées | machine, architecture (x86 / ARM), accélérateur (CPU ou Hailo), précision (FP32 / INT8), runtime (ONNX Runtime, LiteRT, HailoRT), résolution d'entrée (320 / 640) |
| Métriques | latence p50/p95/p99 (inférence seule et pipeline complet), FPS soutenus, mémoire max (RSS), temps de chargement, température et throttling, mAP mesurée sur la cible |
| Énergie | sur les Pi : JT-TC66C en point B (enregistrement de la trace par son logiciel, horodatée pour l'aligner sur les runs), recoupé avec `vcgencmd pmic_read_adc` sur le Pi 5 et `hailortcli` pour la température du Hailo ; puissance idle mesurée 60 s avant, avec accélérateur et caméra branchés ; énergie par inférence |
| Mesure | warm-up écarté, ≥ 60 s par configuration, timestamps par étape, mêmes images rejouées sur chaque machine |
| Analyse | 5 répétitions, médiane + IQR, CDF de latence, front de Pareto latence × énergie × précision |

Sur le Dell XPS et le MacBook M5, la puissance n'est pas mesurable avec le TC66C : seules latence et précision y sont comparées, et le rapport le dit. Sur le Pi 5 + Hailo, vérifier la part des opérateurs exécutés sur le Hailo et ceux qui retombent sur le CPU.

## Optionnel

- Autres accélérateurs du labo : carte NXP avec NPU (TP du 09/12), Coral TPU, Jetson Orin.
- Core ML sur le MacBook, Apache TVM (cours du 06/01).
- Classe `feu_orange` séparée de `feu_rouge`, si le robot doit distinguer l'orange.
- Classe `passage_pieton`.

## Exclus

- Entraînement sur les Raspberry Pi (PC ou cloud uniquement).
- Suivi de ligne et logique de décision (dans `trafficBot`).
- Classement des machines sur les TOPS annoncés par les fabricants.

## Interface avec trafficBot

| Élément | Contrat |
| --- | --- |
| Classes | `stop`, `sens_interdit`, `interdit_gauche`, `interdit_droite`, `feu_rouge` (rouge ou orange), `feu_vert` ; `passage_pieton` en option |
| Livraison | `model.onnx` + `model_int8.tflite` + `labels.txt` en release GitHub versionnée |
| Entrée | image RGB 320×320, prétraitement dans un `preprocess.py` partagé |
| Sortie attendue côté ROS2 | `/traffic/detections` (`vision_msgs/Detection2DArray` : classe, score, boîte) |
| Budget de latence | p95 < 100 ms capture → détection sur le Pi 4 du robot |
| Données | rosbags fournis par `trafficBot` (simulation et circuit réel) |

Le benchmark doit répondre à la question de `trafficBot` : détection sur le Pi 4 du robot, ou image déportée vers un PC par DDS. Il dit aussi ce que gagnerait un robot équipé d'un Pi 5 + Hailo.

La méthode de détection du chemin (ruban adhésif, feuilles imprimées, bordures + LiDAR) est encore à choisir côté `trafficBot`. Elle change l'apparence du sol dans les images du dataset : la collecte définitive attend ce choix (prévu avant le 02/12/2026).

## Livrables (attendus du cours)

- **Rapport de 15 pages maximum** : contexte et objectifs, capteur et ses sources d'incertitude, pipeline de prétraitement, architecture et graphe de calcul, critères d'optimisation, protocole de benchmark, résultats.
- **Ce repo** : scripts d'entraînement, d'export et de benchmark lançables en une commande, configs, logs bruts, versions (OS, runtimes, compilateurs), README permettant à une autre équipe de reproduire les résultats.
- **Présentation PoC** : 15 min + 5 min de questions, le 20/01/2027.

## Jalons (revues du cours Edge AI)

| Date | Séance | Jalon |
| --- | --- | --- |
| 25/11/2026 | Protocole de benchmark | Exigences chiffrées, brouillon du protocole en 8 étapes |
| 02/12/2026 | TinyML | Panneaux imprimés, première collecte d'images, annotation |
| 09/12/2026 | TP NXP | Modèle v0 entraîné, export ONNX |
| 16/12/2026 | ONNX Runtime | Modèle v1, variantes FP32 et INT8, scripts de benchmark |
| 06/01/2027 | Apache TVM | Campagne de mesures sur les 5 configurations |
| 13/01/2027 | Développement | Analyse, abaques, rédaction du rapport |
| 20/01/2027 | Soutenance finale | Rapport + PoC |

## Risques

- Opérateurs non supportés après quantification : vérifier la couverture et la précision sur la cible.
- Dataset trop petit ou trop proche de la simulation : mélanger réel et Gazebo, documenter les limites.
- Throttling thermique des Pi : refroidissement fixe, température logguée pendant chaque run.
- Opérateurs du modèle non supportés par le Hailo : choisir une architecture présente dans le Hailo Model Zoo (YOLO nano par exemple).
