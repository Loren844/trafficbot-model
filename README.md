# trafficbot-model

Projet du cours Edge AI (Polytech, 2026-2027).

Ce dépôt contient le modèle de détection des panneaux et des feux utilisé par le robot du dépôt [trafficBot](https://github.com/MatveiMKS/trafficBot), son optimisation pour des cartes embarquées et le benchmark de ses performances.

## Classes détectées

`stop`, `sens_interdit`, `interdit_gauche`, `interdit_droite`, `feu_rouge` (rouge ou orange), `feu_vert` ; `passage_pieton` en option

## Machines du benchmark

| Machine | Accélérateur |
| --- | --- |
| Raspberry Pi 4 (4 Go) | CPU |
| Raspberry Pi 5 | CPU |
| Raspberry Pi 5 | Hailo |
| Dell XPS (x86, Linux) | CPU |
| MacBook M5 (Apple Silicon) | CPU |

Capteur : Raspberry Pi Camera. Consommation mesurée avec un wattmètre USB-C JT-TC66C (Raspberry Pi uniquement).

## Formats prévus

- `model.onnx` (ONNX Runtime)
- `model_int8.tflite` (TFLite)
- `model.hef` (Hailo)
- `labels.txt`

Les versions du modèle sont publiées en release GitHub.

## Livrables du cours

- Rapport de 15 pages maximum
- Présentation de 15 minutes, le 20/01/2027
- Ce dépôt, avec les scripts et les logs nécessaires pour reproduire les résultats

## Documentation

- [docs/SCOPE.md](docs/SCOPE.md) : périmètre, protocole de benchmark, jalons, répartition

## Conventions de commit

Les messages suivent [Conventional Commits](https://www.conventionalcommits.org/fr/v1.0.0/) :

```
<type>(<portée>): <description>
```

- `type` : voir le tableau ci-dessous.
- `portée` : optionnelle, la partie du dépôt concernée (par exemple `dataset`, `train`, `export`, `bench`, `hailo`).
- `description` : à l'impératif, en minuscules, sans point final, 72 caractères maximum.
- Un changement incompatible est signalé par `!` après le type (`feat!: ...`) ou par une ligne `BREAKING CHANGE:` dans le corps.

| Type | Usage |
| --- | --- |
| `feat` | nouvelle fonctionnalité |
| `fix` | correction de bug |
| `docs` | documentation uniquement |
| `refactor` | modification du code sans changement de comportement |
| `test` | ajout ou modification de tests |
| `perf` | amélioration des performances |
| `build` | dépendances, configuration de build |
| `chore` | maintenance (fichiers ignorés, scripts annexes) |

Exemples :

```
feat(export): ajouter la quantification INT8 en TFLite
fix(bench): exclure le warm-up du calcul des percentiles
docs(bench): décrire le placement du TC66C
```
