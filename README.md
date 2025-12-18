# Vocalyx

Plateforme de transcription audio automatique basée sur une architecture microservices.

## Architecture

Vocalyx est composé de trois modules principaux :

- **vocalyx-api** : API centrale REST et WebSocket pour la gestion des transcriptions
- **vocalyx-frontend** : Interface web dashboard pour l'administration et le suivi
- **vocalyx-transcribe** : Workers Celery pour le traitement audio avec Whisper

### Infrastructure

- **PostgreSQL** : Base de données relationnelle pour le stockage des métadonnées
- **Redis** : Broker de messages pour Celery et cache
- **Docker Compose** : Orchestration des services

## Structure du projet

```
vocalyx-all/
├── vocalyx-api/          # API centrale
├── vocalyx-frontend/     # Interface web
├── vocalyx-transcribe/   # Workers de transcription
├── shared/               # Ressources partagées
│   ├── logs/            # Fichiers de logs
│   ├── uploads/         # Fichiers audio uploadés
│   └── models/          # Modèles Whisper (transcription)
├── docker-compose.yml    # Configuration Docker Compose
└── Makefile             # Commandes de gestion
```

## Démarrage rapide

### Prérequis

- Docker et Docker Compose
- 8 GB de RAM minimum (16 GB recommandé pour les workers)
- Espace disque suffisant pour les modèles Whisper (~2-5 GB selon les modèles choisis)

### Installation

```bash
# Installation complète
make install

# Ou manuellement
docker-compose build
docker-compose up -d
make init-db
```

### Accès aux services

- **Frontend** : http://localhost:8080
- **API** : http://localhost:8000
- **Documentation API** : http://localhost:8000/docs

## Commandes principales

```bash
# Démarrer tous les services
make up

# Arrêter tous les services
make down

# Voir les logs
make logs

# Vérifier la santé des services
make health

# Initialiser la base de données
make init-db

# Sauvegarder la base de données
make db-backup
```

Voir `make help` pour la liste complète des commandes.

## Configuration

La configuration se fait via les variables d'environnement dans `docker-compose.yml` :

- **Base de données** : `DATABASE_URL`
- **Redis** : `REDIS_URL`, `CELERY_BROKER_URL`
- **Sécurité** : `ADMIN_PROJECT_NAME`
- **Logging** : `LOG_LEVEL`, `LOG_FILE_PATH`

## Documentation

- Documentation des logs : `DOCUMENTATION_LOGS.md`
- Documentation API : http://localhost:8000/docs (une fois l'API démarrée)

## Modules

### vocalyx-api

API centrale FastAPI exposant :
- Endpoints REST pour la gestion des transcriptions, projets et utilisateurs
- WebSocket pour les mises à jour en temps réel
- Authentification JWT
- Intégration Celery pour la distribution des tâches

### vocalyx-frontend

Interface web FastAPI avec :
- Dashboard de gestion des transcriptions
- Authentification utilisateur
- Interface d'administration
- Communication WebSocket pour les mises à jour temps réel

### vocalyx-transcribe

Workers Celery pour :
- Transcription audio avec Whisper (OpenAI)
- Diarisation des locuteurs (Pyannote)
- Traitement audio (VAD, segmentation)
- Cache de modèles pour optimiser les performances

## Technologies principales

- **FastAPI** : Framework web asynchrone Python
- **Celery** : Système de files d'attente distribuées
- **PostgreSQL** : Base de données relationnelle
- **Redis** : Broker de messages et cache
- **Whisper** : Modèle de transcription audio OpenAI
- **Pyannote** : Bibliothèque de diarisation des locuteurs
- **Docker** : Conteneurisation et orchestration

