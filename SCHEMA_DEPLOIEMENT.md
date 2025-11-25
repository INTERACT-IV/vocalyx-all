# Schéma de Déploiement - Vocalyx

## Architecture Microservices avec Haute Disponibilité

```mermaid
graph TB
    subgraph "Clients"
        CLIENT[Client HTTP/WebSocket]
        CLIENT_API[Client API Direct]
    end

    subgraph "Load Balancer"
        HAPROXY[HAProxy<br/>Port 8000<br/>Load Balancing Round-Robin]
        HAPROXY_STATS[HAProxy Stats<br/>Port 8404]
    end

    subgraph "Frontend - OPTIONNEL"
        FRONTEND[Vocalyx Frontend<br/>Port 8080<br/>Dashboard Web]
    end

    subgraph "API - Scalable/HA"
        API1[API Instance 01<br/>vocalyx-api-01<br/>Port 8000]
        API2[API Instance 02<br/>vocalyx-api-02<br/>Port 8000]
        API_N[API Instance N<br/>...<br/>Scalable]
    end

    subgraph "Workers Transcription - Scalable/HA"
        TRANS1[Transcribe Worker 01<br/>Queue: transcription<br/>4 CPU / 8GB RAM]
        TRANS2[Transcribe Worker 02<br/>Queue: transcription<br/>4 CPU / 8GB RAM]
        TRANS3[Transcribe Worker 03<br/>Queue: transcription<br/>4 CPU / 8GB RAM]
        TRANS_N[Transcribe Worker N<br/>...<br/>Scalable]
    end

    subgraph "Workers Enrichissement - Scalable/HA"
        ENRICH1[Enrichment Worker 01<br/>Queue: enrichment<br/>4 CPU / 4GB RAM]
        ENRICH2[Enrichment Worker 02<br/>Queue: enrichment<br/>4 CPU / 4GB RAM]
        ENRICH_N[Enrichment Worker N<br/>...<br/>Scalable]
    end

    subgraph "Infrastructure"
        REDIS[(Redis<br/>Celery Broker<br/>Result Backend<br/>Cache)]
        POSTGRES[(PostgreSQL<br/>Base de données<br/>Métadonnées)]
    end

    subgraph "Monitoring - OPTIONNEL"
        FLOWER[Flower<br/>Port 5555<br/>Monitoring Celery]
    end

    subgraph "Stockage Partagé"
        UPLOADS[Volume: uploads<br/>Fichiers audio]
        MODELS[Volume: models<br/>Modèles Whisper/Pyannote/LLM]
        LOGS[Volume: logs<br/>Logs applicatifs]
    end

    %% Flux Clients
    CLIENT -->|HTTP/WebSocket| HAPROXY
    CLIENT_API -->|API REST| HAPROXY
    FRONTEND -.->|Optionnel| HAPROXY

    %% Flux Load Balancer vers API
    HAPROXY -->|Round-Robin<br/>Sticky Sessions| API1
    HAPROXY -->|Round-Robin<br/>Sticky Sessions| API2
    HAPROXY -.->|Scalable| API_N

    %% Flux API vers Infrastructure
    API1 -->|Read/Write| POSTGRES
    API2 -->|Read/Write| POSTGRES
    API_N -.->|Read/Write| POSTGRES
    API1 -->|Publish Tasks| REDIS
    API2 -->|Publish Tasks| REDIS
    API_N -.->|Publish Tasks| REDIS

    %% Flux Workers Transcription
    REDIS -->|Consume Tasks| TRANS1
    REDIS -->|Consume Tasks| TRANS2
    REDIS -->|Consume Tasks| TRANS3
    REDIS -.->|Consume Tasks| TRANS_N
    TRANS1 -->|Update Status| HAPROXY
    TRANS2 -->|Update Status| HAPROXY
    TRANS3 -->|Update Status| HAPROXY
    TRANS_N -.->|Update Status| HAPROXY

    %% Flux Workers Enrichissement
    REDIS -->|Consume Tasks| ENRICH1
    REDIS -->|Consume Tasks| ENRICH2
    REDIS -.->|Consume Tasks| ENRICH_N
    ENRICH1 -->|Update Status| HAPROXY
    ENRICH2 -->|Update Status| HAPROXY
    ENRICH_N -.->|Update Status| HAPROXY

    %% Flux Monitoring
    FLOWER -.->|Monitor| REDIS

    %% Flux Stockage
    API1 -->|Read/Write| UPLOADS
    API2 -->|Read/Write| UPLOADS
    TRANS1 -->|Read| UPLOADS
    TRANS2 -->|Read| UPLOADS
    TRANS3 -->|Read| UPLOADS
    TRANS1 -->|Read| MODELS
    TRANS2 -->|Read| MODELS
    TRANS3 -->|Read| MODELS
    ENRICH1 -->|Read| MODELS
    ENRICH2 -->|Read| MODELS
    API1 -->|Write| LOGS
    API2 -->|Write| LOGS
    TRANS1 -->|Write| LOGS
    TRANS2 -->|Write| LOGS
    TRANS3 -->|Write| LOGS
    ENRICH1 -->|Write| LOGS
    ENRICH2 -->|Write| LOGS
    FRONTEND -->|Write| LOGS

    %% Styles
    classDef scalable fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef optional fill:#fff3e0,stroke:#e65100,stroke-width:2px,stroke-dasharray: 5 5
    classDef infrastructure fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef storage fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px

    class API1,API2,API_N,TRANS1,TRANS2,TRANS3,TRANS_N,ENRICH1,ENRICH2,ENRICH_N scalable
    class FRONTEND,FLOWER optional
    class REDIS,POSTGRES infrastructure
    class UPLOADS,MODELS,LOGS storage
```

## Description des Composants

### 🔄 Load Balancer
- **HAProxy** : Point d'entrée unique (port 8000)
  - Load balancing Round-Robin entre instances API
  - Sticky sessions pour WebSocket
  - Health checks automatiques
  - Stats disponibles sur port 8404

### 🌐 Frontend (OPTIONNEL)
- **Vocalyx Frontend** : Interface web dashboard
  - Port 8080
  - Peut être désactivé si accès API direct uniquement
  - Communique avec l'API via HAProxy

### 🚀 API - Scalable / Haute Disponibilité
- **Instances multiples** : 2+ instances (actuellement 2)
  - Chaque instance : 1GB RAM
  - Load balancing via HAProxy
  - Partage la même base PostgreSQL
  - Sticky sessions pour WebSocket
  - **Scalable** : Ajouter des instances selon la charge

### 🎙️ Workers Transcription - Scalable / Haute Disponibilité
- **Instances multiples** : 3+ workers (actuellement 3)
  - Queue Celery : `transcription`
  - Chaque worker : 4 CPU / 8GB RAM
  - Traitement parallèle des fichiers audio
  - Utilise Whisper + Pyannote
  - **Scalable** : Ajouter des workers selon la charge

### ✨ Workers Enrichissement - Scalable / Haute Disponibilité
- **Instances multiples** : 2+ workers (actuellement 2)
  - Queue Celery : `enrichment`
  - Chaque worker : 4 CPU / 4GB RAM
  - Traitement LLM (Mistral, Phi-3)
  - **Scalable** : Ajouter des workers selon la charge

### 💾 Infrastructure
- **PostgreSQL** : Base de données relationnelle
  - Stockage des métadonnées (utilisateurs, projets, transcriptions)
  - Partagée par toutes les instances API
  
- **Redis** : Broker de messages et cache
  - Celery Broker (distribution des tâches)
  - Result Backend (résultats des tâches)
  - Cache applicatif

### 📊 Monitoring (OPTIONNEL)
- **Flower** : Interface de monitoring Celery
  - Port 5555
  - Visualisation des workers et tâches
  - Peut être désactivé en production

### 💿 Stockage Partagé
- **uploads/** : Fichiers audio uploadés
- **models/** : Modèles ML (Whisper, Pyannote, LLM)
- **logs/** : Logs applicatifs de tous les services

## Flux de Données

### 1. Upload et Transcription
```
Client → HAProxy → API Instance → Redis (Task)
                                    ↓
                            Transcribe Worker
                                    ↓
                            HAProxy → API Instance → PostgreSQL
```

### 2. Enrichissement
```
API Instance → Redis (Task)
                ↓
        Enrichment Worker
                ↓
        HAProxy → API Instance → PostgreSQL
```

### 3. WebSocket (Temps Réel)
```
Client → HAProxy (Sticky Session) → API Instance → WebSocket Manager
```

### 4. Frontend Dashboard
```
Frontend → HAProxy → API Instance → PostgreSQL
```

## Scalabilité

### API
- **Actuellement** : 2 instances
- **Scalable** : Ajouter `vocalyx-api-03`, `vocalyx-api-04`, etc.
- **HAProxy** : Détecte automatiquement les nouvelles instances (via health checks)

### Workers Transcription
- **Actuellement** : 3 workers
- **Scalable** : Ajouter `vocalyx-transcribe-04`, `vocalyx-transcribe-05`, etc.
- **Distribution** : Celery distribue automatiquement les tâches

### Workers Enrichissement
- **Actuellement** : 2 workers
- **Scalable** : Ajouter `vocalyx-enrichment-03`, `vocalyx-enrichment-04`, etc.
- **Distribution** : Celery distribue automatiquement les tâches

## Haute Disponibilité

- ✅ **API** : Plusieurs instances avec load balancing
- ✅ **Workers** : Plusieurs workers par queue (failover automatique)
- ✅ **PostgreSQL** : Peut être mis en cluster (recommandé en production)
- ✅ **Redis** : Peut être mis en cluster/sentinel (recommandé en production)
- ✅ **Health Checks** : Tous les services ont des health checks
- ✅ **Auto-restart** : Tous les conteneurs ont `restart: unless-stopped`

## Ports Exposés

| Service | Port | Description |
|---------|------|-------------|
| HAProxy | 8000 | API REST et WebSocket |
| HAProxy Stats | 8404 | Statistiques HAProxy |
| Frontend | 8080 | Dashboard web (optionnel) |
| PostgreSQL | 5432 | Base de données |
| Redis | 6379 | Broker Celery |
| Flower | 5555 | Monitoring Celery (optionnel) |

## Notes de Déploiement

1. **Frontend optionnel** : Peut être désactivé si accès API direct uniquement
2. **Scalabilité horizontale** : Tous les services applicatifs (API, Transcribe, Enrichment) sont conçus pour être multipliés
3. **Volumes partagés** : Les volumes `uploads`, `models`, et `logs` sont partagés entre tous les services
4. **Réseau** : Tous les services communiquent via le réseau Docker `vocalyx-network`
5. **Sécurité** : Utiliser `INTERNAL_API_KEY` pour les communications internes

