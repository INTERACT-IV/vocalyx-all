# Documentation Technique des Logs - Vocalyx

**Version:** 1.0  
**Date:** 2025-01-19  
**Public cible:** Équipe exploitante et technique

---

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Format des logs](#format-des-logs)
3. [Niveaux de log](#niveaux-de-log)
4. [Module vocalyx-api](#module-vocalyx-api)
5. [Module vocalyx-frontend](#module-vocalyx-frontend)
6. [Module vocalyx-transcribe](#module-vocalyx-transcribe)
7. [Guide d'exploitation](#guide-dexploitation)
8. [Annexes](#annexes)

---

## Vue d'ensemble

Vocalyx est une application microservices composée de trois modules principaux, chacun générant ses propres logs dans le répertoire `./shared/logs/` :

- **vocalyx-api** : API centrale REST et WebSocket (`vocalyx-api.log`)
- **vocalyx-frontend** : Interface web dashboard (`vocalyx-frontend.log`)
- **vocalyx-transcribe** : Workers de transcription audio (`vocalyx-transcribe-01.log`, `vocalyx-transcribe-02.log`, etc.)

### Localisation des fichiers de logs

```
./shared/logs/
├── vocalyx-api.log
├── vocalyx-frontend.log
├── vocalyx-transcribe-01.log
└── vocalyx-transcribe-02.log
```

---

## Format des logs

### Format standard

Tous les modules utilisent un format uniforme :

```
%(asctime)s [%(levelname)s] %(name)s: %(message)s
```

**Exemple :**
```
2025-01-19 17:11:42 [INFO] vocalyx: ✅ Logging configured
```

### Composants du format

| Composant | Description | Exemple |
|-----------|-------------|---------|
| `asctime` | Date et heure au format ISO | `2025-01-19 17:11:42` |
| `levelname` | Niveau de log (voir section suivante) | `INFO`, `ERROR`, `WARNING` |
| `name` | Nom du logger (module/fichier) | `vocalyx`, `api.endpoints`, `uvicorn.access` |
| `message` | Message de log | `✅ Logging configured` |

### Format de date

Format ISO standard : `YYYY-MM-DD HH:MM:SS`

---

## Niveaux de log

### Hiérarchie des niveaux

```
DEBUG < INFO < WARNING < ERROR < CRITICAL
```

### Description des niveaux

| Niveau | Description | Usage | Action requise |
|--------|-------------|-------|----------------|
| **DEBUG** | Informations détaillées pour le débogage | Développement, diagnostic approfondi | Aucune |
| **INFO** | Informations normales sur le fonctionnement | Opérations courantes, événements importants | Surveillance |
| **WARNING** | Avertissements, situations anormales non bloquantes | Problèmes récupérables, configurations non optimales | Investigation |
| **ERROR** | Erreurs nécessitant une attention | Échecs d'opérations, exceptions | Intervention |
| **CRITICAL** | Erreurs critiques menaçant la disponibilité | Pannes système, erreurs non récupérables | Intervention immédiate |

### Configuration du niveau de log

Le niveau de log est configuré via la variable d'environnement `LOG_LEVEL` dans `docker-compose.yml` :

- **Production** : `INFO` (recommandé)
- **Développement** : `DEBUG`
- **Diagnostic** : `DEBUG`

---

## Module vocalyx-api

### Fichier de log

**Chemin :** `./shared/logs/vocalyx-api.log`  
**Logger principal :** `vocalyx`, `api.*`, `uvicorn.*`

### Catégories de logs

#### 1. Démarrage et arrêt

| Message | Niveau | Description |
|---------|--------|-------------|
| `🚀 Démarrage de Vocalyx API` | INFO | Démarrage de l'application |
| `📊 Database: <host>:<port>/<db>` | INFO | Connexion à la base de données |
| `📮 Redis Broker: <url>` | INFO | Connexion au broker Redis |
| `📁 Upload Directory: <path>` | INFO | Répertoire d'upload configuré |
| `🛑 Arrêt de Vocalyx API` | INFO | Arrêt propre de l'application |
| `Tâches de fond arrêtées.` | INFO | Tâches asynchrones terminées |

**Exemple :**
```
2025-01-19 17:11:42 [INFO] vocalyx: 🚀 Démarrage de Vocalyx API
2025-01-19 17:11:42 [INFO] vocalyx: 📊 Database: postgres:5432/vocalyx_db
2025-01-19 17:11:42 [INFO] vocalyx: 📮 Redis Broker: redis://redis:6379/0
```

#### 2. Redis Pub/Sub

| Message | Niveau | Description |
|---------|--------|-------------|
| `📡 Abonné au canal Redis 'vocalyx_updates'` | INFO | Abonnement au canal Pub/Sub |
| `📬 Message Pub/Sub reçu: <message>` | INFO | Message reçu via Pub/Sub |
| `✅ Transcription <id> envoyée directement via WebSocket` | INFO | Diffusion d'une transcription mise à jour |
| `-> Trigger de mise à jour diffusé à tous les clients.` | INFO | Notification de mise à jour envoyée |
| `🛑 Tâche Pub/Sub annulée.` | INFO | Arrêt de la tâche Pub/Sub |
| `❌ Erreur critique Pub/Sub: <error>` | ERROR | Erreur dans le système Pub/Sub |
| `Redis Pub/Sub listener arrêté.` | INFO | Arrêt du listener Pub/Sub |

**Exemple :**
```
2025-01-19 17:11:42 [INFO] vocalyx: 📡 Abonné au canal Redis 'vocalyx_updates'
2025-01-19 17:14:42 [INFO] vocalyx: 📬 Message Pub/Sub reçu: update_abc123
```

#### 3. WebSocket

| Message | Niveau | Description |
|---------|--------|-------------|
| `WebSocket: 🔌 Nouvelle connexion entrante` | INFO | Nouvelle connexion WebSocket |
| `WebSocket: ✅ Connexion acceptée (accept() réussi)` | INFO | Connexion WebSocket acceptée |
| `WebSocket: Token présent: True/False` | INFO | Présence du token JWT |
| `WebSocket: 🔐 Décodage du JWT...` | INFO | Début du décodage du token |
| `WebSocket: ✅ Token décodé avec succès. Username: '<user>'` | INFO | Authentification réussie |
| `WebSocket: ❌ 'sub' manquant dans le JWT` | WARNING | Token JWT invalide |
| `WebSocket: ❌ Erreur JWT: <error>` | ERROR | Erreur lors du décodage JWT |
| `WebSocket: 🔍 Recherche de l'utilisateur '<user>' dans la DB...` | INFO | Vérification de l'utilisateur |
| `WebSocket: ❌ Utilisateur '<user>' non trouvé dans la DB` | WARNING | Utilisateur inexistant |
| `WebSocket: ✅✅✅ Client '<user>' AUTHENTIFIÉ AVEC SUCCÈS !` | INFO | Authentification complète réussie |
| `WebSocket: ✅ Client '<user>' ajouté au ConnectionManager` | INFO | Client enregistré |
| `WebSocket: 📊 Récupération de l'état initial du dashboard...` | INFO | Envoi de l'état initial |
| `WebSocket: 📤 Envoi de l'état initial (DB uniquement) à '<user>'...` | INFO | Diffusion de l'état initial |
| `WebSocket: ✅ État initial (DB) envoyé avec succès !` | INFO | État initial envoyé |
| `WebSocket: 📊 Récupération des stats Celery en arrière-plan...` | INFO | Récupération des stats workers |
| `WebSocket: 📤 Envoi des stats Celery à '<user>'...` | INFO | Diffusion des stats workers |
| `WebSocket: ✅ Stats Celery envoyées avec succès !` | INFO | Stats envoyées |
| `WebSocket: ❌ Erreur lors de la récupération des stats Celery: <error>` | ERROR | Erreur lors de la récupération des stats |
| `WebSocket: ♾️ Entrée dans la boucle keep-alive pour '<user>'` | INFO | Boucle de maintien de connexion |
| `WebSocket: Message JSON reçu de '<user>': <type>` | DEBUG | Message reçu du client |
| `WebSocket: Demande 'get_dashboard_state' reçue avec payload: <payload>` | INFO | Demande d'état du dashboard |
| `WebSocket: État filtré récupéré. Envoi au client...` | INFO | Envoi de l'état filtré |
| `WebSocket: 👋 Client '<user>' déconnecté proprement` | INFO | Déconnexion propre |
| `WebSocket: ⚠️ Erreur dans la boucle keep-alive: <error>` | WARNING | Erreur dans la boucle |
| `WebSocket: 👋 Déconnexion détectée (WebSocketDisconnect)` | INFO | Déconnexion détectée |
| `WebSocket: ❌ Erreur critique: <error>` | ERROR | Erreur critique WebSocket |
| `WebSocket: 🧹 Nettoyage des ressources pour '<user>'...` | INFO | Nettoyage des ressources |
| `WebSocket: ✅ Connexion fermée et nettoyée` | INFO | Connexion fermée |

**Exemple :**
```
2025-01-19 17:14:42 [INFO] api.endpoints: ======================================================================
2025-01-19 17:14:42 [INFO] api.endpoints: WebSocket: 🔌 Nouvelle connexion entrante
2025-01-19 17:14:42 [INFO] api.endpoints: WebSocket: ✅ Connexion acceptée (accept() réussi)
2025-01-19 17:14:42 [INFO] api.endpoints: WebSocket: ✅✅✅ Client 'admin' AUTHENTIFIÉ AVEC SUCCÈS !
```

#### 4. Authentification

| Message | Niveau | Description |
|---------|--------|-------------|
| `Auth success: User '<user>' authenticated` | INFO | Authentification réussie |
| `JWT invalid: User '<user>' not found in DB` | WARNING | Utilisateur non trouvé |
| `JWT stale: Admin status mismatch for user '<user>'` | WARNING | Statut admin modifié |

**Exemple :**
```
2025-01-19 17:14:41 [INFO] api.auth: Auth success: User 'admin' authenticated
```

#### 5. Endpoints REST

| Message | Niveau | Description |
|---------|--------|-------------|
| `-> get_dashboard_state: Démarrage avec filtres: <filters>` | INFO | Début de récupération de l'état |
| `-> get_dashboard_state: Session DB créée.` | INFO | Session base de données créée |
| `-> get_dashboard_state: Lancement de get_celery_stats dans un thread...` | INFO | Début récupération stats Celery |
| `-> get_dashboard_state: Lancement de get_db_data_sync dans un thread...` | INFO | Début récupération données DB |
| `-> get_dashboard_state: Attente de asyncio.gather (Celery + DB)...` | INFO | Attente des résultats |
| `-> get_dashboard_state: asyncio.gather terminé.` | INFO | Résultats récupérés |
| `-> get_dashboard_state: ❌ Erreur lors de asyncio.gather: <error>` | ERROR | Erreur lors de la récupération |
| `-> get_dashboard_state: Fusion des stats DB et Celery...` | INFO | Fusion des statistiques |
| `-> get_dashboard_state: Fusion terminée.` | INFO | Fusion terminée |
| `-> get_dashboard_state: Combinaison des résultats...` | INFO | Combinaison des résultats |
| `Admin created new user: <user> (is_admin=<bool>)` | INFO | Création d'un utilisateur |
| `Assigned project '<project>' to user '<user>'` | INFO | Attribution d'un projet |
| `Removed project '<project>' from user '<user>'` | INFO | Retrait d'un projet |
| `Admin reset password for user: <user>` | INFO | Réinitialisation de mot de passe |
| `Admin deleted user: <user>` | INFO | Suppression d'un utilisateur |
| `✅ Project '<project>' created` | INFO | Projet créé |
| `Error creating project: <error>` | ERROR | Erreur lors de la création |
| `Failed to save file: <error>` | ERROR | Erreur lors de l'enregistrement |
| `Database error: <error>` | ERROR | Erreur base de données |
| `[<id>] Transcription created for project '<project>' \| Task: <task_id>` | INFO | Transcription créée |
| `Failed to enqueue Celery task: <error>` | ERROR | Erreur lors de l'envoi à Celery |
| `[<id>] Updated: <data>` | INFO | Transcription mise à jour |
| `Error updating transcription: <error>` | ERROR | Erreur lors de la mise à jour |
| `[<id>] File deleted: <filename>` | INFO | Fichier supprimé |
| `[<id>] Failed to delete file: <error>` | WARNING | Erreur lors de la suppression |
| `[<id>] Transcription deleted` | INFO | Transcription supprimée |

**Exemple :**
```
2025-01-19 17:14:42 [INFO] api.endpoints: -> get_dashboard_state: Démarrage avec filtres: {'page': 1, 'limit': 25}
2025-01-19 17:14:42 [INFO] api.endpoints: -> get_dashboard_state: Session DB créée.
```

#### 6. Accès HTTP (Uvicorn)

| Message | Niveau | Description |
|---------|--------|-------------|
| `<ip>:<port> - "GET /health HTTP/1.1" 200` | INFO | Requête HTTP réussie |
| `<ip>:<port> - "POST /api/auth/token HTTP/1.1" 200` | INFO | Authentification réussie |
| `<ip>:<port> - "GET /api/user/projects HTTP/1.1" 200` | INFO | Récupération de projets |
| `('172.18.0.1', 58006) - "WebSocket /api/ws/updates?token=..." [accepted]` | INFO | Connexion WebSocket acceptée |
| `connection open` | INFO | Connexion WebSocket ouverte |

**Exemple :**
```
2025-01-19 17:11:46 [INFO] uvicorn.access: 127.0.0.1:56966 - "GET /health HTTP/1.1" 200
2025-01-19 17:14:41 [INFO] uvicorn.access: 172.18.0.6:44182 - "POST /api/auth/token HTTP/1.1" 200
```

#### 7. Statistiques Workers

| Message | Niveau | Description |
|---------|--------|-------------|
| `📊 Polling des stats workers...` | DEBUG | Début du polling |
| `✅ Stats workers diffusées (changement détecté)` | DEBUG | Stats mises à jour |
| `⏭️ Stats workers inchangées, pas de diffusion` | DEBUG | Pas de changement |
| `🛑 Tâche de stats workers annulée.` | INFO | Arrêt du polling |
| `❌ Erreur Polling Stats Workers: <error>` | ERROR | Erreur lors du polling |
| `📊 Stats DB calculées pour <count> workers: <stats>` | INFO | Statistiques calculées |
| `📤 Envoi des stats workers avec DB stats: <count> workers` | INFO | Envoi des stats |

#### 8. Base de données

| Message | Niveau | Description |
|---------|--------|-------------|
| `Projet '<name>' trouvé.` | INFO | Projet trouvé |
| `Projet '<name>' non trouvé. Création...` | WARNING | Création d'un projet |
| `✅ Projet '<name>' créé avec la clé: <key>...` | INFO | Projet créé |
| `Erreur lors de la création du projet: <error>` | ERROR | Erreur lors de la création |
| `✅ Tables de base de données créées` | WARNING | Initialisation DB |
| `✅ Projet admin '<name>' prêt` | WARNING | Projet admin initialisé |
| `🔑 Clé API Admin (<name>): <key>` | WARNING | Clé API admin affichée |
| `Utilisateur 'admin' non trouvé. Création...` | WARNING | Création utilisateur admin |
| `✅ Utilisateur 'admin' créé avec le mot de passe 'admin'` | WARNING | Utilisateur admin créé |
| `✅ Utilisateur 'admin' déjà existant.` | WARNING | Utilisateur admin existant |

**Exemple :**
```
2025-01-19 17:11:42 [WARNING] database: ✅ Tables de base de données créées
2025-01-19 17:11:42 [WARNING] database: ✅ Projet admin 'ISICOMTECH' prêt
```

### Loggers utilisés

- `vocalyx` : Logger principal de l'application
- `api.endpoints` : Endpoints REST et WebSocket
- `api.auth` : Authentification
- `api.websocket_manager` : Gestionnaire WebSocket
- `uvicorn` : Serveur ASGI
- `uvicorn.access` : Accès HTTP
- `uvicorn.error` : Erreurs Uvicorn
- `database` : Opérations base de données

---

## Module vocalyx-frontend

### Fichier de log

**Chemin :** `./shared/logs/vocalyx-frontend.log`  
**Logger principal :** `vocalyx`, `routes`, `api_client`

### Catégories de logs

#### 1. Démarrage et arrêt

| Message | Niveau | Description |
|---------|--------|-------------|
| `🚀 Démarrage de Vocalyx Dashboard` | INFO | Démarrage de l'application |
| `🔗 API URL: <url>` | INFO | URL de l'API configurée |
| `✅ API connection successful` | INFO | Connexion à l'API réussie |
| `❌ API connection failed: <error>` | ERROR | Échec de connexion à l'API |
| `📋 Admin project name: <name>` | INFO | Nom du projet admin |
| `⚠️ Could not verify admin project: <error>` | WARNING | Impossible de vérifier le projet admin |
| `🛑 Arrêt de Vocalyx Dashboard` | INFO | Arrêt propre de l'application |

**Exemple :**
```
2025-01-19 17:11:42 [INFO] vocalyx: 🚀 Démarrage de Vocalyx Dashboard
2025-01-19 17:11:42 [INFO] vocalyx: 🔗 API URL: http://vocalyx-api:8000
2025-01-19 17:11:42 [INFO] vocalyx: ✅ API connection successful
```

#### 2. Authentification

| Message | Niveau | Description |
|---------|--------|-------------|
| `Login successful for user '<user>'` | INFO | Connexion réussie |
| `Login failed: No token received for user '<user>'` | WARNING | Échec de connexion (pas de token) |
| `Login failed for user '<user>': <error>` | ERROR | Erreur lors de la connexion |
| `Login failed: <error>` | ERROR | Erreur générale de connexion |

**Exemple :**
```
2025-01-19 17:14:41 [INFO] application.services.auth_service: Login successful for user 'admin'
```

#### 3. Client API

| Message | Niveau | Description |
|---------|--------|-------------|
| `API Client initialized: <url>` | INFO | Client API initialisé |
| `Error logging into API: <error>` | ERROR | Erreur lors de la connexion à l'API |
| `Error getting user profile: <error>` | ERROR | Erreur lors de la récupération du profil |
| `Error getting user projects: <error>` | ERROR | Erreur lors de la récupération des projets |
| `Error getting admin API key: <error>` | ERROR | Erreur lors de la récupération de la clé admin |
| `Error creating project: <error>` | ERROR | Erreur lors de la création d'un projet |
| `Error listing projects: <error>` | ERROR | Erreur lors de la liste des projets |
| `Error getting project details: <error>` | ERROR | Erreur lors des détails d'un projet |
| `Error creating transcription: <error>` | ERROR | Erreur lors de la création d'une transcription |
| `Error getting user transcriptions: <error>` | ERROR | Erreur lors de la récupération des transcriptions |
| `Error counting user transcriptions: <error>` | ERROR | Erreur lors du comptage |
| `Error getting user transcription: <error>` | ERROR | Erreur lors de la récupération d'une transcription |
| `Error deleting transcription: <error>` | ERROR | Erreur lors de la suppression |
| `Error listing users: <error>` | ERROR | Erreur lors de la liste des utilisateurs |
| `Error creating user: <error>` | ERROR | Erreur lors de la création d'un utilisateur |
| `Error assigning project: <error>` | ERROR | Erreur lors de l'attribution d'un projet |
| `Error removing project: <error>` | ERROR | Erreur lors du retrait d'un projet |
| `Error deleting user: <error>` | ERROR | Erreur lors de la suppression d'un utilisateur |
| `Error getting workers status: <error>` | ERROR | Erreur lors de la récupération des stats workers |
| `Health check failed: <error>` | ERROR | Échec du health check |

**Exemple :**
```
2025-01-19 17:11:42 [INFO] infrastructure.api.api_client: API Client initialized: http://vocalyx-api:8000
```

#### 4. Routes (Endpoints)

| Message | Niveau | Description |
|---------|--------|-------------|
| `Error listing projects: <error>` | ERROR | Erreur dans la route de liste des projets |
| `Error creating project: <error>` | ERROR | Erreur dans la route de création |
| `Error getting project details: <error>` | ERROR | Erreur dans la route de détails |
| `Error getting user projects: <error>` | ERROR | Erreur dans la route des projets utilisateur |
| `Error uploading audio: <error>` | ERROR | Erreur lors de l'upload |
| `Error getting transcriptions: <error>` | ERROR | Erreur lors de la récupération |
| `Error counting transcriptions: <error>` | ERROR | Erreur lors du comptage |
| `Error getting transcription: <error>` | ERROR | Erreur lors de la récupération d'une transcription |
| `Error deleting transcription: <error>` | ERROR | Erreur lors de la suppression |
| `Error getting workers status: <error>` | ERROR | Erreur lors de la récupération des stats |
| `Error proxying list_users: <error>` | ERROR | Erreur proxy liste utilisateurs |
| `Error proxying create_user: <error>` | ERROR | Erreur proxy création utilisateur |
| `Error proxying assign_project: <error>` | ERROR | Erreur proxy attribution projet |
| `Error proxying remove_project: <error>` | ERROR | Erreur proxy retrait projet |
| `Error proxying delete_user: <error>` | ERROR | Erreur proxy suppression utilisateur |
| `Erreur lors de la récupération des données utilisateur: <error>` | ERROR | Erreur lors de la récupération des données |

#### 5. Services applicatifs

| Message | Niveau | Description |
|---------|--------|-------------|
| `Error creating transcription: <error>` | ERROR | Erreur dans le service de transcription |
| `Error listing transcriptions: <error>` | ERROR | Erreur dans le service de liste |
| `Error counting transcriptions: <error>` | ERROR | Erreur dans le service de comptage |
| `Error getting transcription '<id>': <error>` | ERROR | Erreur dans le service de récupération |
| `Error getting user projects: <error>` | ERROR | Erreur dans le service de projets |
| `Error creating project '<name>': <error>` | ERROR | Erreur dans le service de création |
| `Error listing projects: <error>` | ERROR | Erreur dans le service de liste |
| `Error listing users: <error>` | ERROR | Erreur dans le service utilisateurs |
| `Error creating user '<user>': <error>` | ERROR | Erreur dans le service de création |
| `Error assigning project to user: <error>` | ERROR | Erreur dans le service d'attribution |
| `Error removing project from user: <error>` | ERROR | Erreur dans le service de retrait |
| `Error deleting user '<id>': <error>` | ERROR | Erreur dans le service de suppression |

### Loggers utilisés

- `vocalyx` : Logger principal
- `routes` : Routes FastAPI
- `infrastructure.api.api_client` : Client API
- `application.services.*` : Services applicatifs
- `uvicorn` : Serveur ASGI
- `uvicorn.access` : Accès HTTP

---

## Module vocalyx-transcribe

### Fichier de log

**Chemin :** `./shared/logs/vocalyx-transcribe-<instance>.log`  
**Logger principal :** `vocalyx`, `worker`, `transcription_service`, `audio_utils`

### Catégories de logs

#### 1. Démarrage et initialisation

| Message | Niveau | Description |
|---------|--------|-------------|
| `Worker <pid> initialisé pour monitoring psutil.` | INFO | Initialisation du monitoring |
| `Erreur lors de l'initialisation de psutil: <error>` | ERROR | Erreur d'initialisation |
| `Initialisation du client API pour ce worker (<instance>)...` | INFO | Initialisation du client API |
| `API Client initialized: <url>` | INFO | Client API initialisé |
| `✅ API connection verified` | INFO | Connexion API vérifiée |
| `⚠️ API health check returned: <status>` | WARNING | Health check anormal |
| `❌ API connection failed: <error>` | ERROR | Échec de connexion API |
| `⚠️ Worker will start but may fail to process tasks` | ERROR | Avertissement de démarrage |
| `🚀 Starting Celery worker: <instance>` | INFO | Démarrage du worker Celery |

**Exemple :**
```
2025-01-19 17:11:42 [INFO] vocalyx: Worker 1234 initialisé pour monitoring psutil.
2025-01-19 17:11:42 [INFO] vocalyx: Initialisation du client API pour ce worker (worker-01)...
```

#### 2. Gestion des modèles Whisper

| Message | Niveau | Description |
|---------|--------|-------------|
| `✅ Using cached Whisper model: <model>` | INFO | Utilisation d'un modèle en cache |
| `🗑️ Removing least recently used model from cache: <model>` | INFO | Suppression d'un modèle du cache |
| `🚀 Loading Whisper model into cache: <model> (cache: <current>/<max>)` | INFO | Chargement d'un modèle dans le cache |
| `✅ Model <model> loaded and cached successfully` | INFO | Modèle chargé avec succès |
| `❌ Failed to load model <model>: <error>` | ERROR | Échec du chargement d'un modèle |
| `🚀 Loading Whisper model: <path> (requested: <model>)` | INFO | Chargement d'un modèle Whisper |
| `📊 Device: <device> \| Compute: <type>` | INFO | Configuration du modèle |
| `✅ Whisper model loaded successfully` | INFO | Modèle chargé |
| `⚙️ VAD: <enabled> \| Beam size: <size> \| Best of: <best>` | INFO | Paramètres de transcription |
| `ℹ️ Diarization service initialized but model not available (will be skipped if requested)` | INFO | Service de diarisation non disponible |
| `✅ Diarization service initialized and ready` | INFO | Service de diarisation prêt |
| `⚠️ Failed to initialize diarization service: <error> (will be skipped if requested)` | WARNING | Échec d'initialisation de la diarisation |

**Exemple :**
```
2025-01-19 17:11:42 [INFO] vocalyx: 🚀 Loading Whisper model into cache: small (cache: 1/2)
2025-01-19 17:11:42 [INFO] vocalyx: ✅ Model small loaded and cached successfully
```

#### 3. Tâches de transcription

| Message | Niveau | Description |
|---------|--------|-------------|
| `[<id>] 🎯 Task started by worker <instance>` | INFO | Début d'une tâche |
| `[<id>] 📡 Fetching transcription data from API...` | INFO | Récupération des données |
| `Transcription <id> not found` | ERROR | Transcription introuvable |
| `HTTP error getting transcription: <error>` | ERROR | Erreur HTTP |
| `Error getting transcription: <error>` | ERROR | Erreur lors de la récupération |
| `[<id>] 📁 File: <path> \| VAD: <bool> \| Diarization: <bool> \| Model: <model>` | INFO | Paramètres de la transcription |
| `[<id>] ⚙️ Status updated to 'processing'` | INFO | Statut mis à jour |
| `[<id>] 🎤 Getting transcription service with model: <model> (cached)` | INFO | Récupération du service |
| `[<id>] 🎤 Starting transcription with Whisper...` | INFO | Début de la transcription |
| `[<id>] ✅ Transcription service completed` | INFO | Transcription terminée |
| `[<id>] ✅ Transcription completed \| Duration: <duration>s \| Processing: <time>s \| Segments: <count>` | INFO | Transcription réussie |
| `[<id>] 💾 Saving results to API...` | INFO | Sauvegarde des résultats |
| `[<id>] 💾 Results saved to API` | INFO | Résultats sauvegardés |
| `[<id>] ❌ Error: <error>` | ERROR | Erreur lors de la transcription |
| `[<id>] Failed to update error status: <error>` | ERROR | Erreur lors de la mise à jour |
| `[<id>] ⏳ Retrying in <delay>s...` | WARNING | Nouvelle tentative |
| `[<id>] ⛔ All retries exhausted` | ERROR | Toutes les tentatives échouées |
| `[<id>] Status updated to 'processing'` | INFO | Statut mis à jour |
| `[<id>] Error updating status to processing: <error>` | ERROR | Erreur lors de la mise à jour |
| `[<id>] Results saved to API` | INFO | Résultats sauvegardés |
| `[<id>] Error saving results: <error>` | ERROR | Erreur lors de la sauvegarde |
| `[<id>] Marked as error: <message>` | ERROR | Transcription marquée en erreur |
| `[<id>] Error marking as error: <error>` | ERROR | Erreur lors du marquage |

**Exemple :**
```
2025-01-19 17:15:00 [INFO] vocalyx: [abc123] 🎯 Task started by worker worker-01
2025-01-19 17:15:00 [INFO] vocalyx: [abc123] 📡 Fetching transcription data from API...
2025-01-19 17:15:01 [INFO] vocalyx: [abc123] 📁 File: /app/shared_uploads/audio.wav | VAD: True | Diarization: False | Model: small
2025-01-19 17:15:01 [INFO] vocalyx: [abc123] ⚙️ Status updated to 'processing'
```

#### 4. Traitement audio

| Message | Niveau | Description |
|---------|--------|-------------|
| `Audio duration: <duration>s (via soundfile)` | DEBUG | Durée audio détectée |
| `⚠️ Could not get duration with soundfile: <error>` | WARNING | Erreur soundfile |
| `Audio duration: <duration>s (via pydub)` | DEBUG | Durée via pydub |
| `❌ Could not get duration: <error>` | ERROR | Impossible de déterminer la durée |
| `Preprocessing audio: <filename>` | DEBUG | Début du prétraitement |
| `🔍 Audio format detected: STEREO/MONO (<channels> channel(s))` | INFO | Format audio détecté |
| `✅ Preserved STEREO version for diarization: <filename>` | INFO | Version stéréo préservée |
| `💡 STEREO audio: one channel per speaker (optimized for diarization)` | INFO | Optimisation stéréo |
| `ℹ️ STEREO detected but preservation disabled` | INFO | Stéréo détecté mais non préservé |
| `ℹ️ MONO audio: using mono version for both transcription and diarization` | INFO | Utilisation mono |
| `✅ Audio preprocessed: <filename>` | INFO | Prétraitement terminé |
| `⚠️ Preprocessing failed, using original: <error>` | WARNING | Échec du prétraitement |
| `🎤 VAD: Detected <count> speech segments` | INFO | Segments de parole détectés |
| `⚠️ VAD failed, using full audio: <error>` | WARNING | Échec VAD |
| `⚠️ Could not get duration with soundfile, using pydub: <error>` | WARNING | Fallback pydub |
| `📊 Audio court (<duration>s), pas de découpe` | INFO | Audio court, pas de découpe |
| `🎯 Using time-based segmentation with VAD (faster-whisper will handle VAD filtering)` | INFO | Segmentation temporelle avec VAD |
| `🎯 Created <count> time-based segments (VAD will be applied by faster-whisper)` | INFO | Segments créés |
| `📊 Using time-based segmentation (<length>ms chunks)` | INFO | Segmentation temporelle |
| `📊 Audio moyen (<duration>s), découpe en 2` | INFO | Découpe moyenne |
| `📊 Audio long (<duration>s), découpe en <count> segments` | INFO | Découpe longue |
| `❌ Segmentation error: <error>` | ERROR | Erreur de segmentation |
| `🧹 Deleted segment: <filename>` | DEBUG | Segment supprimé |
| `⚠️ Could not delete segment <filename>: <error>` | WARNING | Erreur de suppression |

**Exemple :**
```
2025-01-19 17:15:01 [INFO] audio_utils: 🔍 Audio format detected: STEREO (2 channel(s))
2025-01-19 17:15:01 [INFO] audio_utils: ✅ Preserved STEREO version for diarization: audio_stereo.wav
2025-01-19 17:15:01 [INFO] audio_utils: ✅ Audio preprocessed: audio_mono.wav
```

#### 5. Transcription Whisper

| Message | Niveau | Description |
|---------|--------|-------------|
| `🎯 Starting Whisper transcription (VAD: <bool>)...` | INFO | Début de la transcription |
| `🎯 Whisper inference completed, consuming generator...` | INFO | Inférence terminée |
| `✅ Generator consumed, got <count> segments in <time>s` | INFO | Génération terminée |
| `❌ Error during transcription/consumption: <error>` | ERROR | Erreur lors de la transcription |
| `⚠️ Retrying WITHOUT VAD...` | WARNING | Nouvelle tentative sans VAD |
| `❌ 'info' n'a pas été retourné par model.transcribe(), impossible de détecter la langue.` | ERROR | Impossible de détecter la langue |
| `📝 Converting <count> segments to dict...` | INFO | Conversion des segments |
| `📝 Processed <current>/<total> segments` | INFO | Progression du traitement |
| `❌ Error processing segment <index>: <error>` | ERROR | Erreur lors du traitement d'un segment |
| `✅ All <count> segments processed` | INFO | Tous les segments traités |
| `⚡ Starting parallel transcription: <count> segments with <workers> worker(s)` | INFO | Début transcription parallèle |
| `✅ Segment <index>/<total> completed (<done>/<total> done)` | INFO | Segment terminé |
| `❌ Error transcribing segment <index>: <error>` | ERROR | Erreur lors de la transcription d'un segment |
| `✅ Parallel transcription completed: <count> total segments` | INFO | Transcription parallèle terminée |
| `📁 Processing file: <filename> \| VAD requested: <bool>` | INFO | Traitement d'un fichier |
| `📏 Audio duration: <duration>s` | INFO | Durée audio |
| `✨ Audio preprocessed: MONO for Whisper, STEREO preserved for diarization` | INFO | Prétraitement avec stéréo |
| `✨ Audio preprocessed: MONO (stereo not detected or diarization disabled)` | INFO | Prétraitement mono |
| `🔪 Created <count> segment(s) (adaptive size: <size>ms)` | INFO | Segments créés |
| `⚡ Parallel transcription: <count> segments with <workers> worker(s)` | INFO | Transcription parallèle |
| `🎤 Transcribing single segment...` | INFO | Transcription d'un seul segment |
| `🎤 Running speaker diarization...` | INFO | Début de la diarisation |
| `🎯 Using STEREO audio for diarization (optimal: one channel per speaker)` | INFO | Utilisation stéréo pour diarisation |
| `🎯 Using MONO audio for diarization` | INFO | Utilisation mono pour diarisation |
| `✅ Speaker diarization completed and assigned to segments` | INFO | Diarisation terminée |
| `⚠️ Diarization returned no segments` | WARNING | Diarisation sans résultat |
| `❌ Error during diarization: <error>` | ERROR | Erreur lors de la diarisation |
| `⚠️ Diarization requested but service not available (check model configuration)` | WARNING | Service de diarisation non disponible |
| `🧹 Temporary files cleaned` | DEBUG | Fichiers temporaires nettoyés |
| `⚠️ Cleanup error: <error>` | WARNING | Erreur lors du nettoyage |

**Exemple :**
```
2025-01-19 17:15:02 [INFO] transcription_service: 🎯 Starting Whisper transcription (VAD: True)...
2025-01-19 17:15:05 [INFO] transcription_service: ✅ Generator consumed, got 45 segments in 3.2s
2025-01-19 17:15:05 [INFO] transcription_service: ✅ All 45 segments processed
```

#### 6. Configuration et performance

| Message | Niveau | Description |
|---------|--------|-------------|
| `🔍 Detected CPU: <count> core(s)` | INFO | CPU détecté |
| `⚙️ Adaptive segmentation: CPU faible (<count> cores) → segments de 25s` | INFO | Segmentation adaptative faible |
| `⚙️ Adaptive segmentation: CPU moyen (<count> cores) → segments de 35s` | INFO | Segmentation adaptative moyen |
| `⚙️ Adaptive segmentation: CPU puissant (<count> cores) → segments de 45s` | INFO | Segmentation adaptative puissant |

#### 7. Health check et monitoring

| Message | Niveau | Description |
|---------|--------|-------------|
| `get_worker_health_handler appelé avant initialisation de psutil.` | WARNING | Health check avant initialisation |
| `Erreur dans get_worker_health_handler: <error>` | ERROR | Erreur dans le health check |
| `Error updating transcription: <error>` | ERROR | Erreur lors de la mise à jour |

### Loggers utilisés

- `vocalyx` : Logger principal
- `worker` : Worker Celery
- `transcription_service` : Service de transcription
- `audio_utils` : Utilitaires audio
- `diarization` : Service de diarisation
- `api_client` : Client API
- `celery` : Framework Celery
- `celery.task` : Tâches Celery
- `celery.worker` : Workers Celery

---

## Guide d'exploitation

### Consultation des logs

#### Via Docker Compose

```bash
# Tous les services
docker-compose logs -f

# Service spécifique
docker-compose logs -f vocalyx-api
docker-compose logs -f vocalyx-frontend
docker-compose logs -f vocalyx-transcribe-01

# Dernières lignes
docker-compose logs --tail=100 vocalyx-api
```

#### Via fichiers

```bash
# Suivre en temps réel
tail -f ./shared/logs/vocalyx-api.log

# Dernières lignes
tail -n 100 ./shared/logs/vocalyx-api.log

# Recherche
grep "ERROR" ./shared/logs/vocalyx-api.log
grep "transcription_id" ./shared/logs/vocalyx-transcribe-01.log
```

### Surveillance des erreurs

#### Commandes utiles

```bash
# Compter les erreurs
grep -c "ERROR" ./shared/logs/*.log

# Erreurs récentes (dernières 100 lignes)
tail -n 100 ./shared/logs/*.log | grep "ERROR"

# Erreurs par service
grep "ERROR" ./shared/logs/vocalyx-api.log | tail -20
grep "ERROR" ./shared/logs/vocalyx-frontend.log | tail -20
grep "ERROR" ./shared/logs/vocalyx-transcribe-*.log | tail -20
```

#### Alertes à surveiller

| Message | Module | Action |
|---------|--------|--------|
| `❌ Erreur critique` | API | Vérifier la connectivité Redis/DB |
| `❌ API connection failed` | Frontend | Vérifier la disponibilité de l'API |
| `❌ Failed to load model` | Transcribe | Vérifier les modèles Whisper |
| `⛔ All retries exhausted` | Transcribe | Analyser l'erreur de transcription |
| `Database error` | API | Vérifier la connexion PostgreSQL |
| `❌ Échec de connexion à Redis` | API | Vérifier Redis |

### Analyse des performances

#### Temps de traitement

```bash
# Extraire les temps de traitement
grep "Processing:" ./shared/logs/vocalyx-transcribe-*.log | awk '{print $NF}'

# Statistiques
grep "Processing:" ./shared/logs/vocalyx-transcribe-*.log | \
  awk -F'Processing: ' '{print $2}' | \
  awk -F's' '{print $1}' | \
  awk '{sum+=$1; count++} END {print "Moyenne:", sum/count, "s"}'
```

#### Utilisation des modèles

```bash
# Modèles chargés
grep "Loading Whisper model" ./shared/logs/vocalyx-transcribe-*.log

# Utilisation du cache
grep "Using cached Whisper model" ./shared/logs/vocalyx-transcribe-*.log
```

### Rotation des logs

Les logs ne sont pas automatiquement rotatés. Pour éviter une croissance excessive :

#### Solution 1 : Rotation manuelle

```bash
# Archiver les anciens logs
mv ./shared/logs/vocalyx-api.log ./shared/logs/vocalyx-api.log.$(date +%Y%m%d)

# Vider le fichier
> ./shared/logs/vocalyx-api.log
```

#### Solution 2 : Configuration logrotate (recommandé)

Créer `/etc/logrotate.d/vocalyx` :

```
/path/to/vocalyx-all/shared/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    sharedscripts
    postrotate
        docker-compose -f /path/to/vocalyx-all/docker-compose.yml restart vocalyx-api vocalyx-frontend vocalyx-transcribe-01
    endscript
}
```

### Diagnostic de problèmes courants

#### Problème : API non accessible

**Symptômes :**
```
[ERROR] vocalyx-frontend: ❌ API connection failed: Connection refused
```

**Actions :**
1. Vérifier le statut du service : `docker-compose ps vocalyx-api`
2. Vérifier les logs : `docker-compose logs vocalyx-api`
3. Vérifier la connectivité réseau : `docker-compose exec vocalyx-frontend ping vocalyx-api`

#### Problème : Transcription en échec

**Symptômes :**
```
[ERROR] vocalyx: [<id>] ❌ Error: <error>
[ERROR] vocalyx: [<id>] ⛔ All retries exhausted
```

**Actions :**
1. Identifier l'erreur dans les logs
2. Vérifier la disponibilité du fichier audio
3. Vérifier les ressources (mémoire, CPU)
4. Vérifier les modèles Whisper

#### Problème : WebSocket déconnecté

**Symptômes :**
```
[INFO] api.endpoints: WebSocket: 👋 Client '<user>' déconnecté proprement
```

**Actions :**
1. Vérifier la stabilité réseau
2. Vérifier les timeouts WebSocket
3. Vérifier les logs côté client (navigateur)

### Métriques à surveiller

#### API

- Nombre de requêtes HTTP par minute
- Temps de réponse moyen
- Taux d'erreur (ERROR / total)
- Nombre de connexions WebSocket actives

#### Frontend

- Taux d'échec de connexion à l'API
- Erreurs d'authentification
- Erreurs de récupération de données

#### Transcribe

- Nombre de transcriptions par heure
- Temps de traitement moyen
- Taux de succès (done / total)
- Utilisation du cache de modèles
- Utilisation mémoire/CPU

---

## Annexes

### A. Codes d'erreur HTTP courants

| Code | Signification | Log associé |
|------|---------------|-------------|
| 200 | Succès | `uvicorn.access: ... 200` |
| 401 | Non autorisé | `Login failed` |
| 404 | Non trouvé | `Transcription <id> not found` |
| 500 | Erreur serveur | `Database error`, `Error creating transcription` |

### B. Structure des messages de log

#### Format standard
```
<timestamp> [<level>] <logger>: <message>
```

#### Format avec contexte
```
<timestamp> [<level>] <logger>: [<context>] <message>
```

Exemple avec contexte :
```
2025-01-19 17:15:00 [INFO] vocalyx: [abc123] 🎯 Task started by worker worker-01
```

### C. Emojis utilisés dans les logs

| Emoji | Signification | Usage |
|-------|---------------|-------|
| ✅ | Succès | Opération réussie |
| ❌ | Erreur | Échec, erreur |
| ⚠️ | Avertissement | Situation anormale non bloquante |
| 🔍 | Recherche/Diagnostic | Opération de recherche |
| 📊 | Statistiques | Données statistiques |
| 🚀 | Démarrage | Démarrage d'un processus |
| 🛑 | Arrêt | Arrêt d'un processus |
| 📡 | Communication | Réseau, API, WebSocket |
| 💾 | Sauvegarde | Enregistrement de données |
| 🎯 | Cible/Objectif | Objectif atteint |
| 🎤 | Audio | Traitement audio |
| 📁 | Fichier | Opération sur fichier |
| ⚙️ | Configuration | Paramètres, configuration |
| 🔐 | Sécurité | Authentification, autorisation |
| 👋 | Déconnexion | Fermeture de connexion |
| 🧹 | Nettoyage | Suppression, nettoyage |

### D. Variables d'environnement de logging

| Variable | Description | Valeurs possibles | Défaut |
|----------|-------------|-------------------|--------|
| `LOG_LEVEL` | Niveau de log | DEBUG, INFO, WARNING, ERROR, CRITICAL | INFO |
| `LOG_COLORED` | Logs colorés (console) | true, false | false |
| `LOG_FILE_PATH` | Chemin du fichier de log | Chemin absolu | `/app/logs/<module>.log` |
| `LOG_FILE_ENABLED` | Activer les logs fichier | true, false | true |

### E. Références

- **Format de log Python** : [logging — Logging facility for Python](https://docs.python.org/3/library/logging.html)
- **Uvicorn logging** : [Uvicorn Logging](https://www.uvicorn.org/settings/#logging)
- **Celery logging** : [Celery Logging](https://docs.celeryproject.org/en/stable/userguide/logging.html)

---

**Document généré le :** 2025-01-19  
**Dernière mise à jour :** 2025-01-19  
**Version de la documentation :** 1.0

