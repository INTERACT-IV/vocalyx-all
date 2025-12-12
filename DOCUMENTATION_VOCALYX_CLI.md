# Documentation d'utilisation de vocalyx_cli

## Table des matières

1. [Introduction](#introduction)
2. [Installation et prérequis](#installation-et-prérequis)
3. [Configuration](#configuration)
4. [Actions disponibles](#actions-disponibles)
5. [Options globales](#options-globales)
6. [Exemples d'utilisation](#exemples-dutilisation)
7. [Variables d'environnement](#variables-denvironnement)
8. [Format de sortie](#format-de-sortie)
9. [Dépannage](#dépannage)

---

## Introduction

`vocalyx_cli` est un outil en ligne de commande permettant d'interagir avec l'API Vocalyx pour la transcription et l'enrichissement de fichiers audio. Il offre une interface simple et puissante pour automatiser vos workflows de transcription.

### Fonctionnalités principales

- **Transcription audio** : Créer des transcriptions à partir de fichiers audio
- **Suivi de statut** : Vérifier l'état d'avancement des transcriptions
- **Enrichissement** : Améliorer les transcriptions avec des modèles LLM
- **Gestion** : Supprimer des transcriptions selon différents critères

---

## Installation et prérequis

### Prérequis

- **Bash** : Le script nécessite un shell bash (version 4.0 ou supérieure)
- **curl** : Pour les requêtes HTTP vers l'API
- **jq** (optionnel) : Pour un meilleur formatage JSON en sortie

### Installation

1. Rendez le script exécutable :
```bash
chmod +x vocalyx_cli
```

2. (Optionnel) Ajoutez le script à votre PATH pour l'utiliser depuis n'importe où :
```bash
sudo cp vocalyx_cli /usr/local/bin/
```

### Vérification de l'installation

```bash
./vocalyx_cli --help
```

---

## Configuration

### Fichier de configuration

Le script peut lire les identifiants depuis un fichier de configuration situé à `~/.vocalyx_config`.

Créez ce fichier avec le contenu suivant :

```bash
# ~/.vocalyx_config
VOCALYX_API_URL=http://localhost:8000
VOCALYX_USERNAME=admin
VOCALYX_PASSWORD=mon_mot_de_passe
VOCALYX_INTERNAL_KEY=secret_key_pour_comms_internes_123456  # Pour l'action purge
```

**Note** : Assurez-vous que le fichier a les bonnes permissions :
```bash
chmod 600 ~/.vocalyx_config
```

### Variables d'environnement

Vous pouvez également définir les variables directement dans votre environnement :

```bash
export VOCALYX_API_URL=http://localhost:8000
export VOCALYX_USERNAME=admin
export VOCALYX_PASSWORD=mon_mot_de_passe
export VOCALYX_PROJECT_API_KEY=clé_api_du_projet  # Optionnel, skip l'authentification
```

---

## Actions disponibles

### 1. transcribe

Crée une transcription audio sur Vocalyx.

#### Syntaxe

```bash
./vocalyx_cli --action=transcribe -f <fichier_audio> -P <nom_projet> [options]
```

#### Arguments requis

- `-f, --file FILE` : Chemin vers le fichier audio à transcrire
- `-P, --project PROJECT` : Nom du projet Vocalyx

#### Options spécifiques

- `-m, --model MODEL` : Modèle Whisper à utiliser
  - Valeurs possibles : `tiny`, `base`, `small`, `medium`, `large-v3-turbo`
  - Défaut : `small`
- `--no-vad` : Désactiver VAD (Voice Activity Detection)
- `--diarization` : Activer la diarisation des locuteurs
- `--enrichment` : Activer l'enrichissement automatique après la transcription (prompts par défaut)
- `--llm-model MODEL` : Modèle LLM pour l'enrichissement
  - Valeurs possibles : `qwen2.5-7b-instruct`, `mistral-7b-instruct`, `phi-3-mini`
- `--wait` : Attendre la fin de la transcription (et de l'enrichissement si activé) et afficher le résultat (mode synchrone)
- `-v, --verbose` : Afficher les messages détaillés (par défaut : JSON uniquement)

#### Exemples

```bash
# Transcription simple
./vocalyx_cli --action=transcribe -f audio.wav -P ISICOMTECH

# Transcription avec modèle medium et diarisation
./vocalyx_cli --action=transcribe --file audio.mp3 --project MON_PROJET --model medium --diarization

# Transcription sans VAD
./vocalyx_cli --action=transcribe -f audio.wav -P ISICOMTECH --no-vad

# Transcription avec attente du résultat
./vocalyx_cli --action=transcribe -f audio.wav -P ISICOMTECH --wait

# Transcription avec enrichissement automatique
./vocalyx_cli --action=transcribe -f audio.wav -P ISICOMTECH --enrichment --wait

# Transcription avec enrichissement et modèle LLM spécifique
./vocalyx_cli --action=transcribe -f audio.wav -P ISICOMTECH --enrichment --llm-model qwen2.5-7b-instruct --wait
```

---

### 2. status

Récupère le statut et le résultat d'une transcription.

#### Syntaxe

```bash
./vocalyx_cli --action=status -tid <transcription_id> [options]
```

#### Arguments requis

- `-tid, --transcription-id ID` : ID de la transcription à récupérer

#### Options spécifiques

- `-v, --verbose` : Afficher les messages détaillés (par défaut : JSON uniquement)

#### Exemples

```bash
# Récupérer le statut d'une transcription
./vocalyx_cli --action=status -tid abc123-def456-ghi789

# Avec messages détaillés
./vocalyx_cli --action=status --transcription-id abc123-def456-ghi789 --verbose
```

#### Statuts possibles

- `pending` : Transcription en attente
- `processing` : Transcription en cours
- `done` : Transcription terminée avec succès
- `error` : Erreur lors de la transcription

---

### 3. enrich

Déclenche l'enrichissement d'une transcription existante.

#### Syntaxe

```bash
./vocalyx_cli --action=enrich -tid <transcription_id> [options]
```

#### Arguments requis

- `-tid, --transcription-id ID` : ID de la transcription à enrichir

#### Options spécifiques

- `-m, --llm-model MODEL` : Modèle LLM à utiliser
  - Valeurs possibles : `qwen2.5-7b-instruct`, `mistral-7b-instruct`, `phi-3-mini`
- `--text-correction` : Activer la correction du texte (orthographe, grammaire)
- `--prompts-file FILE` : Fichier JSON contenant les prompts personnalisés
- `--wait` : Attendre la fin de l'enrichissement et afficher le résultat (mode synchrone)
- `-v, --verbose` : Afficher les messages détaillés (par défaut : JSON uniquement)

#### Exemples

```bash
# Enrichissement simple
./vocalyx_cli --action=enrich -tid abc123-def456-ghi789

# Enrichissement avec correction de texte
./vocalyx_cli --action=enrich --transcription-id abc123 --llm-model qwen2.5-7b-instruct --text-correction

# Enrichissement avec prompts personnalisés
./vocalyx_cli --action=enrich -tid abc123 -m phi-3-mini --prompts-file prompts.json

# Enrichissement avec attente du résultat
./vocalyx_cli --action=enrich -tid abc123 --wait
```

#### Format du fichier de prompts

Le fichier de prompts doit être un JSON valide. Exemple :

```json
{
  "summary": "Résumez ce texte en 3 phrases",
  "keywords": "Extrayez les mots-clés principaux",
  "sentiment": "Analysez le sentiment du texte"
}
```

---

### 4. purge

Supprime des transcriptions selon des critères (fichiers audio inclus).

#### Syntaxe

```bash
./vocalyx_cli --action=purge [options]
```

#### Options (au moins une requise)

- `-tid, --transcription-id ID` : ID de la transcription à supprimer
- `-P, --project PROJECT` : Supprimer toutes les transcriptions d'un projet
- `-d, --date DATE` : Supprimer les transcriptions depuis cette date
  - Format : `YYYY-MM-DD` ou `YYYY-MM-DDTHH:MM:SS`
- `--dry-run` : Afficher les transcriptions qui seraient supprimées sans les supprimer
- `-v, --verbose` : Afficher les messages détaillés (par défaut : JSON uniquement)

#### Exemples

```bash
# Supprimer une transcription spécifique
./vocalyx_cli --action=purge -tid abc123-def456-ghi789

# Supprimer toutes les transcriptions d'un projet
./vocalyx_cli --action=purge -P ISICOMTECH

# Supprimer les transcriptions depuis une date
./vocalyx_cli --action=purge -d 2024-01-01

# Combinaison : supprimer les transcriptions d'un projet depuis une date
./vocalyx_cli --action=purge -P ISICOMTECH -d 2024-01-01

# Mode dry-run pour voir ce qui serait supprimé
./vocalyx_cli --action=purge -P ISICOMTECH --dry-run
```

#### Note importante

L'action `purge` nécessite la clé interne (`INTERNAL_API_KEY` ou `VOCALYX_INTERNAL_KEY`) définie dans votre fichier de configuration. Cette clé est utilisée pour les communications internes avec l'API.

---

## Options globales

Ces options sont disponibles pour toutes les actions :

- `-u, --username USERNAME` : Nom d'utilisateur (défaut : `admin` ou depuis config)
- `-p, --password PASSWORD` : Mot de passe (ou depuis config)
- `-a, --api-url URL` : URL de l'API (défaut : `http://localhost:8000`)
- `-h, --help` : Afficher l'aide

### Aide spécifique à une action

Pour obtenir l'aide détaillée d'une action spécifique :

```bash
./vocalyx_cli --action=transcribe --help
./vocalyx_cli --action=status --help
./vocalyx_cli --action=enrich --help
./vocalyx_cli --action=purge --help
```

---

## Variables d'environnement

| Variable | Description | Défaut |
|----------|-------------|--------|
| `VOCALYX_API_URL` | URL de l'API Vocalyx | `http://localhost:8000` |
| `VOCALYX_USERNAME` | Nom d'utilisateur | `admin` |
| `VOCALYX_PASSWORD` | Mot de passe | (aucun) |
| `VOCALYX_PROJECT_API_KEY` | Clé API du projet (si fournie, skip l'authentification) | (aucun) |
| `VOCALYX_INTERNAL_KEY` | Clé interne pour l'action purge | (aucun) |

---

## Format de sortie

### Mode par défaut (JSON uniquement)

Par défaut, le script affiche uniquement le JSON de réponse sur la sortie standard (`stdout`). Les messages d'erreur sont affichés sur la sortie d'erreur (`stderr`).

Exemple :
```json
{
  "id": "abc123-def456-ghi789",
  "status": "done",
  "project_name": "ISICOMTECH",
  "text": "Transcription du texte..."
}
```

### Mode verbose

Avec l'option `-v` ou `--verbose`, le script affiche :
- Des messages colorés sur l'état d'avancement
- Des informations détaillées sur les opérations
- Le JSON de réponse (si disponible)

### Formatage JSON

Si `jq` est installé, le JSON sera automatiquement formaté. Sinon, le JSON brut sera affiché.

---

## Exemples d'utilisation

### Workflow complet : Transcription avec enrichissement

```bash
# 1. Créer une transcription avec enrichissement automatique
./vocalyx_cli --action=transcribe \
  -f mon_audio.wav \
  -P MON_PROJET \
  --model medium \
  --diarization \
  --enrichment \
  --llm-model qwen2.5-7b-instruct \
  --wait \
  --verbose

# Le résultat complet (transcription + enrichissement) sera affiché
```

### Workflow en deux étapes : Transcription puis enrichissement

```bash
# 1. Créer une transcription
RESULT=$(./vocalyx_cli --action=transcribe -f audio.wav -P MON_PROJET)
TRANSCRIPTION_ID=$(echo $RESULT | jq -r '.id')

# 2. Vérifier le statut
./vocalyx_cli --action=status -tid $TRANSCRIPTION_ID --verbose

# 3. Enrichir la transcription
./vocalyx_cli --action=enrich \
  -tid $TRANSCRIPTION_ID \
  --llm-model qwen2.5-7b-instruct \
  --text-correction \
  --wait \
  --verbose
```

### Nettoyage périodique

```bash
# Supprimer toutes les transcriptions d'un projet créées avant le 1er janvier 2024
./vocalyx_cli --action=purge \
  -P MON_PROJET \
  -d 2024-01-01 \
  --verbose
```

### Utilisation avec des scripts

```bash
#!/bin/bash

# Script pour transcrire plusieurs fichiers
for audio_file in *.wav; do
    echo "Transcription de $audio_file..."
    ./vocalyx_cli --action=transcribe \
      -f "$audio_file" \
      -P MON_PROJET \
      --model small \
      --wait
done
```

---

## Dépannage

### Erreur d'authentification

**Problème** : `❌ Erreur d'authentification`

**Solutions** :
- Vérifiez vos identifiants dans `~/.vocalyx_config`
- Vérifiez que l'URL de l'API est correcte
- Utilisez l'option `--verbose` pour plus de détails

### Fichier audio introuvable

**Problème** : `❌ Fichier audio introuvable`

**Solutions** :
- Vérifiez le chemin du fichier
- Utilisez un chemin absolu si nécessaire
- Vérifiez les permissions du fichier

### Projet non trouvé

**Problème** : `❌ Projet 'NOM_PROJET' non trouvé`

**Solutions** :
- Vérifiez le nom du projet (sensible à la casse)
- Utilisez `--verbose` pour voir la liste des projets disponibles
- Assurez-vous que vous avez accès au projet

### Clé interne requise pour purge

**Problème** : `❌ Clé interne requise pour la suppression`

**Solutions** :
- Ajoutez `INTERNAL_API_KEY` ou `VOCALYX_INTERNAL_KEY` dans `~/.vocalyx_config`
- Contactez l'administrateur pour obtenir la clé interne

### Timeout lors de l'attente

**Problème** : `⚠️ Timeout: la transcription prend plus de temps que prévu`

**Solutions** :
- Le timeout est fixé à 1 heure maximum
- Vérifiez le statut manuellement avec `--action=status`
- Utilisez le mode asynchrone (sans `--wait`) pour les fichiers volumineux

### Format JSON invalide

**Problème** : Erreurs lors du parsing JSON

**Solutions** :
- Installez `jq` pour un meilleur formatage : `sudo apt-get install jq`
- Vérifiez que l'API répond correctement avec `--verbose`

---

## Conseils et bonnes pratiques

1. **Utilisez le mode verbose pour le débogage** : L'option `--verbose` fournit des informations détaillées utiles pour comprendre ce qui se passe.

2. **Sauvegardez les IDs de transcription** : Les IDs sont nécessaires pour suivre et enrichir les transcriptions.

3. **Utilisez --dry-run avant purge** : Testez toujours avec `--dry-run` avant de supprimer des transcriptions.

4. **Mode synchrone vs asynchrone** :
   - Utilisez `--wait` pour les fichiers courts ou lorsque vous avez besoin du résultat immédiatement
   - Sans `--wait`, le script retourne immédiatement et vous pouvez suivre la progression avec `--action=status`

5. **Gestion des erreurs** : Le script utilise `set -e`, donc il s'arrêtera immédiatement en cas d'erreur. Vérifiez les codes de sortie dans vos scripts.

6. **Sécurité** : Ne commitez jamais votre fichier `~/.vocalyx_config` dans un dépôt Git. Utilisez des variables d'environnement ou des secrets managers pour la production.

---

## Support

Pour plus d'informations ou pour signaler un problème, consultez la documentation de l'API Vocalyx ou contactez le support.

---

*Documentation générée pour vocalyx_cli - Version 1.0*

