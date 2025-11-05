# 🎙️ Vocalyx - Audio Transcription Platform

Architecture microservices pour la transcription audio avec Faster-Whisper et Celery.

[![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104-green.svg)](https://fastapi.tiangolo.com/)
[![Celery](https://img.shields.io/badge/Celery-5.3-brightgreen.svg)](https://docs.celeryproject.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)

---

## 📐 Architecture

```
┌──────────────────┐
│   Utilisateur    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  vocalyx-        │────►│  vocalyx-        │────►│   PostgreSQL     │
│  frontend        │     │  api             │     └──────────────────┘
│  (Port 8080)     │     │  (Port 8000)     │
└──────────────────┘     └────────┬─────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                    ▼                           ▼
         ┌──────────────────┐       ┌──────────────────┐
         │   Redis          │       │  vocalyx-        │
         │   (Celery)       │◄──────│  transcribe      │
         └──────────────────┘       │  (Workers)       │
                                    └──────────────────┘
```

### Services

| Service | Port | Rôle |
|---------|------|------|
| **vocalyx-api** | 8000 | API REST centrale, propriétaire de la DB |
| **vocalyx-frontend** | 8080 | Interface web utilisateur |
| **vocalyx-transcribe** | - | Workers Celery pour transcription Whisper |
| **postgres** | 5432 | Base de données |
| **redis** | 6379 | Broker Celery + Cache |
| **flower** | 5555 | Monitoring Celery (optionnel) |

---

## 🚀 Quick Start

### Prérequis

- Docker & Docker Compose
- Git

### Installation Automatique

```bash
# Cloner le dépôt
git clone <repository>
cd vocalyx

# Installation complète (crée .env, build, démarre, initialise la DB)
make install
```

**C'est tout !** L'application est accessible sur :
- Frontend: http://localhost:8080
- API: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Flower: http://localhost:5555

### Installation Manuelle

```bash
# 1. Copier le fichier d'environnement
cp .env.example .env

# 2. Éditer .env et changer les secrets
nano .env

# 3. Créer les répertoires
mkdir -p shared_uploads shared_logs whisper_models backups

# 4. Construire les images
docker-compose build

# 5. Démarrer les services
docker-compose up -d

# 6. Initialiser la base de données
docker-compose exec vocalyx-api python -c "from database import init_db; init_db()"
```

---

## 📋 Commandes Utiles

### Gestion des Services

```bash
# Démarrer tous les services
make up

# Arrêter tous les services
make down

# Redémarrer tous les services
make restart

# Voir les logs en temps réel
make logs

# Statut des conteneurs
make ps

# Vérifier la santé des services
make health
```

### Logs par Service

```bash
make logs-api          # Logs de l'API
make logs-frontend     # Logs du frontend
make logs-worker-01    # Logs du worker 01
make logs-worker-02    # Logs du worker 02
```

### Workers Celery

```bash
# Scaler les workers (exemple: 4 workers)
make scale-workers N=4

# Statut des workers
make celery-status

# Statistiques des workers
make celery-stats

# Purger les tâches en attente
make celery-purge
```

### Base de Données

```bash
# Sauvegarder la DB
make db-backup

# Restaurer la DB
make db-restore FILE=backups/backup.sql

# Shell PostgreSQL
make db-shell
```

### Nettoyage

```bash
# Nettoyer les conteneurs (préserve les volumes)
make clean

# Tout supprimer (⚠️ SUPPRIME LES DONNÉES)
make clean-all

# Nettoyer les uploads
make clean-uploads

# Nettoyer les logs
make clean-logs
```

---

## 🔧 Configuration

### Variables d'Environnement

Éditez le fichier `.env` :

```bash
# Sécurité (⚠️ CHANGER EN PRODUCTION)
INTERNAL_API_KEY=secret_key_pour_comms_internes_123456
ADMIN_PROJECT_NAME=ISICOMTECH

# Base de données
POSTGRES_PASSWORD=vocalyx_secret

# Whisper
WHISPER_MODEL=./models/openai-whisper-small  # tiny, base, small, medium, large
WHISPER_DEVICE=cpu                            # cpu ou cuda (GPU)
WHISPER_LANGUAGE=fr                           # fr, en, es, etc.

# Performance
MAX_WORKERS=2                                 # Concurrence par worker
VAD_ENABLED=true                              # Voice Activity Detection
```

### Configuration Avancée

Chaque service peut être configuré via son `config.ini` :

- `vocalyx-api/config.ini`
- `vocalyx-frontend/config.ini`
- `vocalyx-transcribe/config.ini`

---

## 📊 Monitoring

### Flower (Monitoring Celery)

Accédez à http://localhost:5555 pour visualiser :
- Workers actifs
- Tâches en cours / terminées / échouées
- Statistiques en temps réel

### Health Checks

```bash
# API
curl http://localhost:8000/health

# Frontend
curl http://localhost:8080/health

# Tous les services
make health
```

### Logs

```bash
# Temps réel
make logs

# Logs d'un service spécifique
docker-compose logs -f vocalyx-api
```

---

## 🔒 Sécurité

### ⚠️ IMPORTANT - En Production

1. **Changez les secrets dans `.env`** :
   ```bash
   INTERNAL_API_KEY=<générer_une_clé_forte>
   POSTGRES_PASSWORD=<générer_un_mot_de_passe_fort>
   ```

2. **Utilisez HTTPS** :
   - Mettez un reverse proxy (Nginx, Traefik)
   - Obtenez des certificats SSL (Let's Encrypt)

3. **Limitez les ports exposés** :
   - Ne pas exposer PostgreSQL (5432) publiquement
   - Ne pas exposer Redis (6379) publiquement

4. **Sauvegardez régulièrement** :
   ```bash
   # Créer un cron job pour les backups
   0 2 * * * cd /path/to/vocalyx && make db-backup
   ```

---

## 🎯 Utilisation

### 1. Créer un Projet

Via l'interface web (http://localhost:8080) :
1. Cliquez sur "Gérer les Projets"
2. Créez un nouveau projet
3. Récupérez la clé API générée

### 2. Upload Audio

**Via l'Interface Web** :
1. Sélectionnez le projet
2. Collez la clé API
3. Uploadez votre fichier audio
4. La transcription démarre automatiquement

**Via l'API** :
```bash
curl -X POST http://localhost:8000/api/transcriptions \
  -H "X-API-Key: vk_VOTRE_CLE_API" \
  -F "file=@audio.wav" \
  -F "project_name=mon_projet" \
  -F "use_vad=true"
```

### 3. Consulter les Résultats

- Interface web : http://localhost:8080
- API : http://localhost:8000/docs

---

## 🐛 Dépannage

### Les workers ne se connectent pas

```bash
# Vérifier que Redis est accessible
docker-compose exec vocalyx-transcribe-01 redis-cli -h redis ping

# Vérifier les logs
make logs-worker-01
```

### L'API ne démarre pas

```bash
# Vérifier que PostgreSQL est prêt
docker-compose exec postgres pg_isready -U vocalyx

# Vérifier les logs
make logs-api
```

### "Database not initialized"

```bash
# Initialiser la base de données
make init-db
```

### Modèle Whisper non trouvé

Le modèle est téléchargé automatiquement au premier lancement. Si échec :

```bash
# Télécharger manuellement
docker-compose exec vocalyx-transcribe-01 python -c "
from faster_whisper import WhisperModel
WhisperModel('small', download_root='/app/models')
"
```

---

## 📚 Documentation

- [API Documentation](http://localhost:8000/docs) (Swagger)
- [vocalyx-api README](./vocalyx-api/README.md)
- [vocalyx-frontend README](./vocalyx-frontend/README.md)
- [vocalyx-transcribe README](./vocalyx-transcribe/README.md)

---

## 🏗️ Structure du Projet

```
vocalyx/
├── vocalyx-api/              # API centrale
├── vocalyx-frontend/         # Interface web
├── vocalyx-transcribe/       # Workers Celery
├── shared_uploads/           # Fichiers audio (volume partagé)
├── shared_logs/              # Logs centralisés
├── whisper_models/           # Modèles Whisper (volume)
├── backups/                  # Sauvegardes DB
├── docker-compose.yml        # Orchestration Docker
├── .env.example              # Variables d'environnement
├── Makefile                  # Commandes utiles
└── README.md                 # Ce fichier
```

---

## 🚀 Scalabilité

### Augmenter les Workers

```bash
# Méthode 1 : Via le Makefile
make scale-workers N=5

# Méthode 2 : Via docker-compose
docker-compose up -d --scale vocalyx-transcribe-01=5
```

### Load Balancer (Production)

Pour gérer plusieurs frontends/APIs, utilisez Nginx ou Traefik :

```nginx
upstream vocalyx_api {
    server vocalyx-api-01:8000;
    server vocalyx-api-02:8000;
}

upstream vocalyx_frontend {
    server vocalyx-frontend-01:8080;
    server vocalyx-frontend-02:8080;
}
```

---

## 📝 Changelog

### Version 2.0.0 (Architecture Microservices)
- ✅ Découplage complet des services
- ✅ Communication via API REST
- ✅ File d'attente Celery avec Redis
- ✅ Scalabilité horizontale native
- ✅ Monitoring Celery Flower
- ✅ Multi-projets avec clés API

### Version 1.0.0 (Monolithique)
- Application monolithique
- Accès direct à la DB
- Worker loop interne

---

## 👥 Contributeurs

- Guilhem RICHARD - Architecture & Développement

---

## 📄 Licence

Propriétaire - Tous droits réservés

---

## 🆘 Support

Pour toute question ou problème :
1. Consultez les logs : `make logs`
2. Vérifiez la santé : `make health`
3. Consultez la documentation des services

---

**Vocalyx v2.0** - Powered by FastAPI, Celery & Faster-Whisper 🎙️