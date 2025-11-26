# VOCALYX - Configuration Podman/systemd

Ce répertoire contient les fichiers de configuration quadlet pour déployer Vocalyx avec Podman et systemd.

## Structure des fichiers

- **`.network`** : Définition du réseau `vocalyx-network`
- **`.volume`** : Définitions des volumes persistants (`postgres_data`, `redis_data`)
- **`.container`** : Définitions de tous les conteneurs de l'architecture

## Prérequis

1. **Podman** installé et configuré
2. **systemd** activé
3. Les images Docker construites au préalable (voir ci-dessous)

## Construction des images

### Méthode recommandée : Script automatique

Utilisez le script `build-images.sh` pour construire toutes les images :

```bash
# Construction standard
./build-images.sh

# Construction sans cache (reconstruction complète)
./build-images.sh --no-cache

# Construction avec un tag personnalisé
./build-images.sh --tag v1.0.0

# Construction et push vers un registry
./build-images.sh --push --registry registry.example.com
```

Le script affiche :
- La progression de chaque construction
- Le temps de construction
- La taille des images
- Un résumé final

### Méthode manuelle

Si vous préférez construire manuellement :

```bash
# API
podman build -t vocalyx-api:latest -f ./vocalyx-api/Containerfile ./vocalyx-api

# Frontend
podman build -t vocalyx-frontend:latest -f ./vocalyx-frontend/Containerfile ./vocalyx-frontend

# Transcription Worker
podman build -t vocalyx-transcribe:latest -f ./vocalyx-transcribe/Containerfile ./vocalyx-transcribe

# Enrichment Worker
podman build -t vocalyx-enrichment:latest -f ./vocalyx-enrichment/Containerfile ./vocalyx-enrichment
```

## Déploiement

### Méthode recommandée : Script automatique

Le script `deploy-podman-systemd.sh` automatise tout le processus :

```bash
# Déploiement complet (construit les images si nécessaire)
./deploy-podman-systemd.sh

# Déploiement sans construire les images (suppose qu'elles existent)
./deploy-podman-systemd.sh --skip-build
```

Le script :
1. Vérifie/construit les images (sauf si `--skip-build`)
2. Prépare les fichiers de configuration
3. Installe les fichiers systemd
4. Recharge systemd
5. Démarre tous les services dans le bon ordre

### Méthode manuelle

#### 1. Copier les fichiers dans systemd

```bash
# Créer le répertoire si nécessaire
sudo mkdir -p /etc/containers/systemd

# Copier tous les fichiers de configuration
sudo cp *.network *.volume *.container /etc/containers/systemd/
```

### 2. Ajuster les chemins des volumes

**IMPORTANT** : Les fichiers `.container` utilisent des chemins relatifs pour les volumes montés. 
Vous devez modifier les chemins dans chaque fichier `.container` pour pointer vers le répertoire 
absolu de votre projet.

Par exemple, dans `vocalyx-api-01.container`, remplacez :
```
Volume=%E/shared/uploads:/app/shared_uploads:Z
```

Par le chemin absolu de votre projet :
```
Volume=/home/user/code/vocalyx-all/shared/uploads:/app/shared_uploads:Z
```

Ou utilisez une variable d'environnement si vous préférez.

### 3. Recharger systemd

```bash
sudo systemctl daemon-reload
```

## Démarrage des services

### Ordre de démarrage recommandé

1. **Infrastructure de base** :
```bash
sudo systemctl start vocalyx-network.service
sudo systemctl start vocalyx-postgres-data.service
sudo systemctl start vocalyx-redis-data.service
```

2. **Services de base** :
```bash
sudo systemctl start vocalyx-postgres.service
sudo systemctl start vocalyx-redis.service
```

3. **Services API** :
```bash
sudo systemctl start vocalyx-api-01.service
sudo systemctl start vocalyx-api-02.service
```

4. **HAProxy** :
```bash
sudo systemctl start vocalyx-haproxy.service
```

5. **Frontend** :
```bash
sudo systemctl start vocalyx-frontend.service
```

6. **Workers** :
```bash
sudo systemctl start vocalyx-transcribe-01.service
sudo systemctl start vocalyx-transcribe-02.service
sudo systemctl start vocalyx-transcribe-03.service
sudo systemctl start vocalyx-enrichment-01.service
sudo systemctl start vocalyx-enrichment-02.service
```

7. **Monitoring (optionnel)** :
```bash
sudo systemctl start vocalyx-flower.service
```

### Démarrage automatique au boot

Pour activer le démarrage automatique de tous les services :

```bash
sudo systemctl enable vocalyx-network.service
sudo systemctl enable vocalyx-postgres-data.service
sudo systemctl enable vocalyx-redis-data.service
sudo systemctl enable vocalyx-postgres.service
sudo systemctl enable vocalyx-redis.service
sudo systemctl enable vocalyx-api-01.service
sudo systemctl enable vocalyx-api-02.service
sudo systemctl enable vocalyx-haproxy.service
sudo systemctl enable vocalyx-frontend.service
sudo systemctl enable vocalyx-transcribe-01.service
sudo systemctl enable vocalyx-transcribe-02.service
sudo systemctl enable vocalyx-transcribe-03.service
sudo systemctl enable vocalyx-enrichment-01.service
sudo systemctl enable vocalyx-enrichment-02.service
sudo systemctl enable vocalyx-flower.service
```

## Gestion des services

### Vérifier le statut

```bash
# Tous les services
sudo systemctl status 'vocalyx-*'

# Un service spécifique
sudo systemctl status vocalyx-api-01.service
```

### Voir les logs

```bash
# Logs systemd
sudo journalctl -u vocalyx-api-01.service -f

# Logs du conteneur
sudo podman logs vocalyx-api-01
```

### Arrêter un service

```bash
sudo systemctl stop vocalyx-api-01.service
```

### Redémarrer un service

```bash
sudo systemctl restart vocalyx-api-01.service
```

## Workflow recommandé

### Premier déploiement

```bash
# 1. Construire toutes les images
./build-images.sh

# 2. Déployer (les images sont déjà construites, donc skip-build)
./deploy-podman-systemd.sh --skip-build
```

### Déploiement complet (tout en un)

```bash
# Le script de déploiement construira les images si nécessaire
./deploy-podman-systemd.sh
```

### Mise à jour après modification du code

```bash
# 1. Reconstruire les images modifiées
./build-images.sh --no-cache

# 2. Redémarrer les services affectés
sudo systemctl restart vocalyx-api-01.service
sudo systemctl restart vocalyx-api-02.service
# etc.
```

## Notes importantes

1. **Chemins des volumes** : N'oubliez pas de modifier les chemins absolus dans les fichiers `.container` 
   pour correspondre à votre environnement.

2. **Sécurité** : Les clés secrètes dans les fichiers `.container` sont en clair. En production, 
   utilisez des secrets systemd ou des variables d'environnement sécurisées.

3. **Ressources** : Les limites de mémoire et CPU sont définies dans chaque fichier `.container`. 
   Ajustez-les selon votre infrastructure.

4. **Dépendances** : Les fichiers `.container` incluent des dépendances systemd (`After`, `Requires`, `Wants`) 
   pour gérer l'ordre de démarrage automatiquement.

5. **Healthchecks** : Les healthchecks sont configurés pour chaque service. systemd utilisera ces 
   informations pour gérer les redémarrages.

## Dépannage

### Vérifier que les volumes sont créés

```bash
podman volume ls | grep vocalyx
```

### Vérifier que le réseau est créé

```bash
podman network ls | grep vocalyx
```

### Vérifier les conteneurs en cours d'exécution

```bash
podman ps
```

### Inspecter un conteneur

```bash
podman inspect vocalyx-api-01
```

