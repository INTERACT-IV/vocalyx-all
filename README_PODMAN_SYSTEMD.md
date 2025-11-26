# VOCALYX - Configuration Podman/systemd (Mode Utilisateur)

Ce répertoire contient les fichiers de configuration quadlet pour déployer Vocalyx avec Podman et systemd en **mode utilisateur** (rootless).

**Mode utilisateur par défaut**: `ai-user`

## Structure des fichiers

- **`.network`** : Définition du réseau `vocalyx-network`
- **`.volume`** : Définitions des volumes persistants (`postgres_data`, `redis_data`)
- **`.container`** : Définitions de tous les conteneurs de l'architecture

## Prérequis

1. **Podman** installé et configuré en mode rootless
2. **systemd** activé avec support utilisateur
3. **Utilisateur `ai-user`** créé et configuré (ou utiliser `--user` pour spécifier un autre utilisateur)
4. Les images Docker construites au préalable (voir ci-dessous)

### Configuration de l'utilisateur

Avant de déployer, assurez-vous que l'utilisateur `ai-user` existe et est configuré :

```bash
# Créer l'utilisateur (si nécessaire)
sudo useradd -m -s /bin/bash ai-user

# Activer systemd --user pour cet utilisateur (important pour que les services persistent)
sudo loginctl enable-linger ai-user

# Vérifier que Podman rootless fonctionne
sudo -u ai-user podman info
```

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

#### 1. Copier les fichiers dans systemd (mode utilisateur)

**Note**: Le script `deploy-podman-systemd.sh` fait cela automatiquement. Si vous préférez le faire manuellement :

```bash
# Créer le répertoire systemd utilisateur
sudo -u ai-user mkdir -p ~ai-user/.config/containers/systemd

# Copier tous les fichiers de configuration
sudo -u ai-user cp *.network *.volume *.container ~ai-user/.config/containers/systemd/
```

**Différence importante**: En mode utilisateur, les fichiers vont dans `~/.config/containers/systemd/` et non `/etc/containers/systemd/`.

### 2. Ajuster les chemins des volumes

**IMPORTANT** : Le script `deploy-podman-systemd.sh` remplace automatiquement `%E` par le chemin absolu du projet. Si vous faites l'installation manuelle, vous devez modifier les chemins dans chaque fichier `.container`.

### 3. Recharger systemd (mode utilisateur)

```bash
# Recharger systemd pour l'utilisateur ai-user
sudo -u ai-user systemctl --user daemon-reload
```

**Note**: Utilisez toujours `systemctl --user` et non `systemctl` seul en mode utilisateur.

## Démarrage des services

### Ordre de démarrage recommandé (mode utilisateur)

**Note**: Utilisez `systemctl --user` et exécutez en tant que l'utilisateur `ai-user` :

1. **Infrastructure de base** :
```bash
sudo -u ai-user systemctl --user start vocalyx-network.service
sudo -u ai-user systemctl --user start vocalyx-postgres-data.service
sudo -u ai-user systemctl --user start vocalyx-redis-data.service
```

2. **Services de base** :
```bash
sudo -u ai-user systemctl --user start vocalyx-postgres.service
sudo -u ai-user systemctl --user start vocalyx-redis.service
```

3. **Services API** :
```bash
sudo -u ai-user systemctl --user start vocalyx-api-01.service
sudo -u ai-user systemctl --user start vocalyx-api-02.service
```

4. **HAProxy** :
```bash
sudo -u ai-user systemctl --user start vocalyx-haproxy.service
```

5. **Frontend** :
```bash
sudo -u ai-user systemctl --user start vocalyx-frontend.service
```

6. **Workers** :
```bash
sudo -u ai-user systemctl --user start vocalyx-transcribe-01.service
sudo -u ai-user systemctl --user start vocalyx-transcribe-02.service
sudo -u ai-user systemctl --user start vocalyx-transcribe-03.service
sudo -u ai-user systemctl --user start vocalyx-enrichment-01.service
sudo -u ai-user systemctl --user start vocalyx-enrichment-02.service
```

7. **Monitoring (optionnel)** :
```bash
sudo -u ai-user systemctl --user start vocalyx-flower.service
```

### Démarrage automatique au boot (mode utilisateur)

Pour activer le démarrage automatique de tous les services pour l'utilisateur `ai-user` :

```bash
# Important: Activer linger pour que les services démarrent au boot
sudo loginctl enable-linger ai-user

# Activer les services
sudo -u ai-user systemctl --user enable vocalyx-network.service
sudo -u ai-user systemctl --user enable vocalyx-postgres-data.service
sudo -u ai-user systemctl --user enable vocalyx-redis-data.service
sudo -u ai-user systemctl --user enable vocalyx-postgres.service
sudo -u ai-user systemctl --user enable vocalyx-redis.service
sudo -u ai-user systemctl --user enable vocalyx-api-01.service
sudo -u ai-user systemctl --user enable vocalyx-api-02.service
sudo -u ai-user systemctl --user enable vocalyx-haproxy.service
sudo -u ai-user systemctl --user enable vocalyx-frontend.service
sudo -u ai-user systemctl --user enable vocalyx-transcribe-01.service
sudo -u ai-user systemctl --user enable vocalyx-transcribe-02.service
sudo -u ai-user systemctl --user enable vocalyx-transcribe-03.service
sudo -u ai-user systemctl --user enable vocalyx-enrichment-01.service
sudo -u ai-user systemctl --user enable vocalyx-enrichment-02.service
sudo -u ai-user systemctl --user enable vocalyx-flower.service
```

## Gestion des services

### Vérifier le statut (mode utilisateur)

```bash
# Tous les services
sudo -u ai-user systemctl --user status 'vocalyx-*'

# Un service spécifique
sudo -u ai-user systemctl --user status vocalyx-api-01.service
```

### Voir les logs (mode utilisateur)

```bash
# Logs systemd (mode utilisateur)
sudo -u ai-user journalctl --user -u vocalyx-api-01.service -f

# Logs du conteneur (Podman rootless)
sudo -u ai-user podman logs vocalyx-api-01
```

### Arrêter un service (mode utilisateur)

```bash
sudo -u ai-user systemctl --user stop vocalyx-api-01.service
```

### Redémarrer un service (mode utilisateur)

```bash
sudo -u ai-user systemctl --user restart vocalyx-api-01.service
```

## Workflow recommandé

### Configuration initiale

```bash
# 1. Créer et configurer l'utilisateur ai-user
sudo useradd -m -s /bin/bash ai-user
sudo loginctl enable-linger ai-user

# 2. Vérifier que Podman rootless fonctionne
sudo -u ai-user podman info
```

### Premier déploiement

```bash
# 1. Construire toutes les images (pour ai-user)
sudo -u ai-user ./build-images.sh

# 2. Déployer (les images sont déjà construites, donc skip-build)
./deploy-podman-systemd.sh --skip-build
```

### Déploiement complet (tout en un)

```bash
# Le script de déploiement construira les images si nécessaire (pour ai-user)
./deploy-podman-systemd.sh
```

### Mise à jour après modification du code

```bash
# 1. Reconstruire les images modifiées (pour ai-user)
sudo -u ai-user ./build-images.sh --no-cache

# 2. Redémarrer les services affectés (mode utilisateur)
sudo -u ai-user systemctl --user restart vocalyx-api-01.service
sudo -u ai-user systemctl --user restart vocalyx-api-02.service
# etc.
```

### Utiliser un autre utilisateur

Si vous voulez utiliser un autre utilisateur que `ai-user` :

```bash
./deploy-podman-systemd.sh --user mon-utilisateur
```

## Notes importantes

1. **Mode utilisateur** : Ce déploiement utilise systemd en mode utilisateur (`--user`) avec l'utilisateur `ai-user`. 
   Tous les conteneurs s'exécutent en mode rootless Podman, ce qui est plus sécurisé.

2. **Chemins des volumes** : Le script `deploy-podman-systemd.sh` remplace automatiquement `%E` par le chemin absolu 
   du projet. Si vous faites l'installation manuelle, modifiez les chemins dans les fichiers `.container`.

3. **Sécurité** : Les clés secrètes dans les fichiers `.container` sont en clair. En production, 
   utilisez des secrets systemd ou des variables d'environnement sécurisées.

4. **Ressources** : Les limites de mémoire et CPU sont définies dans chaque fichier `.container`. 
   Ajustez-les selon votre infrastructure.

5. **Dépendances** : Les fichiers `.container` incluent des dépendances systemd (`After`, `Requires`, `Wants`) 
   pour gérer l'ordre de démarrage automatiquement.

6. **Healthchecks** : Les healthchecks sont configurés pour chaque service. systemd utilisera ces 
   informations pour gérer les redémarrages.

7. **Linger** : Assurez-vous que `loginctl enable-linger ai-user` est exécuté pour que les services 
   persistent après la déconnexion de l'utilisateur.

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

