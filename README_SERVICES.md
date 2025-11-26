# VOCALYX - Fichiers .service systemd

Ce répertoire contient les fichiers `.service` systemd pour gérer les conteneurs Podman de Vocalyx.

## Différence avec les fichiers quadlet (.container)

- **Fichiers `.container`** : Format quadlet Podman, plus simple mais moins flexible
- **Fichiers `.service`** : Format systemd traditionnel, plus de contrôle et de flexibilité

Vous pouvez utiliser l'un ou l'autre, ou les deux en parallèle.

## Fichiers disponibles

- `vocalyx-postgres.service` - Base de données PostgreSQL
- `vocalyx-redis.service` - Broker Redis/Celery
- `vocalyx-haproxy.service` - Load balancer HAProxy
- `vocalyx-api-01.service` - Service API #1
- `vocalyx-api-02.service` - Service API #2
- `vocalyx-frontend.service` - Interface frontend
- `vocalyx-transcribe-01.service` - Worker transcription #1
- `vocalyx-transcribe-02.service` - Worker transcription #2
- `vocalyx-transcribe-03.service` - Worker transcription #3
- `vocalyx-enrichment-01.service` - Worker enrichissement #1
- `vocalyx-enrichment-02.service` - Worker enrichissement #2
- `vocalyx-flower.service` - Monitoring Celery (optionnel)

## Installation

### Méthode automatique (recommandée)

```bash
# Installer tous les fichiers .service
./install-services.sh /chemin/vers/vocalyx-all
```

Le script :
1. Configure automatiquement le chemin du projet (`PROJECT_DIR`)
2. Copie les fichiers dans `/etc/systemd/system/`
3. Recharge systemd

### Méthode manuelle

1. **Modifier le chemin du projet** dans chaque fichier `.service` :
   - Ouvrir le fichier
   - Remplacer `/home/shinohk/code/vocalyx-all` par votre chemin

2. **Copier les fichiers** :
   ```bash
   sudo cp *.service /etc/systemd/system/
   ```

3. **Recharger systemd** :
   ```bash
   sudo systemctl daemon-reload
   ```

## Utilisation

### Démarrer un service

```bash
sudo systemctl start vocalyx-postgres.service
```

### Arrêter un service

```bash
sudo systemctl stop vocalyx-postgres.service
```

### Redémarrer un service

```bash
sudo systemctl restart vocalyx-postgres.service
```

### Vérifier le statut

```bash
sudo systemctl status vocalyx-postgres.service
```

### Voir les logs

```bash
# Logs en temps réel
sudo journalctl -u vocalyx-postgres.service -f

# Dernières lignes
sudo journalctl -u vocalyx-postgres.service -n 50

# Logs depuis une date
sudo journalctl -u vocalyx-postgres.service --since "2024-01-01"
```

### Activer le démarrage automatique

```bash
sudo systemctl enable vocalyx-postgres.service
```

### Désactiver le démarrage automatique

```bash
sudo systemctl disable vocalyx-postgres.service
```

## Ordre de démarrage recommandé

1. **Infrastructure** :
   ```bash
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

7. **Monitoring** (optionnel) :
   ```bash
   sudo systemctl start vocalyx-flower.service
   ```

## Gestion de tous les services

### Démarrer tous les services

```bash
sudo systemctl start vocalyx-postgres.service \
  vocalyx-redis.service \
  vocalyx-api-01.service \
  vocalyx-api-02.service \
  vocalyx-haproxy.service \
  vocalyx-frontend.service \
  vocalyx-transcribe-01.service \
  vocalyx-transcribe-02.service \
  vocalyx-transcribe-03.service \
  vocalyx-enrichment-01.service \
  vocalyx-enrichment-02.service \
  vocalyx-flower.service
```

### Arrêter tous les services

```bash
sudo systemctl stop 'vocalyx-*'
```

### Vérifier le statut de tous les services

```bash
sudo systemctl status 'vocalyx-*'
```

### Activer le démarrage automatique pour tous

```bash
sudo systemctl enable vocalyx-postgres.service \
  vocalyx-redis.service \
  vocalyx-api-01.service \
  vocalyx-api-02.service \
  vocalyx-haproxy.service \
  vocalyx-frontend.service \
  vocalyx-transcribe-01.service \
  vocalyx-transcribe-02.service \
  vocalyx-transcribe-03.service \
  vocalyx-enrichment-01.service \
  vocalyx-enrichment-02.service \
  vocalyx-flower.service
```

## Configuration

### Modifier les variables d'environnement

Éditez le fichier `.service` correspondant et modifiez les lignes `--env` dans `ExecStart` :

```bash
sudo systemctl edit vocalyx-api-01.service
```

Ou modifiez directement le fichier :

```bash
sudo nano /etc/systemd/system/vocalyx-api-01.service
sudo systemctl daemon-reload
sudo systemctl restart vocalyx-api-01.service
```

### Modifier les limites de ressources

Dans chaque fichier `.service`, vous pouvez modifier :
- `--memory` : Limite de mémoire (ex: `--memory 2g`)
- `--cpus` : Nombre de CPUs (ex: `--cpus 4`)

## Dépannage

### Service ne démarre pas

1. Vérifier les logs :
   ```bash
   sudo journalctl -u vocalyx-postgres.service -n 100
   ```

2. Vérifier que le conteneur existe :
   ```bash
   podman ps -a | grep vocalyx-postgres
   ```

3. Vérifier que l'image existe :
   ```bash
   podman images | grep postgres
   ```

4. Vérifier le réseau :
   ```bash
   podman network ls | grep vocalyx-network
   ```

### Service redémarre en boucle

1. Vérifier les logs pour identifier l'erreur
2. Vérifier que les dépendances sont démarrées
3. Vérifier les healthchecks dans les logs

### Modifier le chemin du projet après installation

1. Éditer le fichier :
   ```bash
   sudo nano /etc/systemd/system/vocalyx-api-01.service
   ```

2. Modifier la ligne `Environment="PROJECT_DIR=..."`

3. Recharger et redémarrer :
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart vocalyx-api-01.service
   ```

## Notes importantes

1. **Chemin du projet** : Assurez-vous que `PROJECT_DIR` pointe vers le bon répertoire dans chaque fichier `.service`

2. **Réseau** : Les services supposent que le réseau `vocalyx-network` existe. Créez-le avec :
   ```bash
   podman network create vocalyx-network
   ```

3. **Volumes** : Les volumes nommés (`vocalyx-postgres-data`, `vocalyx-redis-data`) doivent exister. Créez-les avec :
   ```bash
   podman volume create vocalyx-postgres-data
   podman volume create vocalyx-redis-data
   ```

4. **Images** : Toutes les images doivent être construites/téléchargées avant de démarrer les services

5. **Permissions** : Les fichiers `.service` doivent être dans `/etc/systemd/system/` et nécessitent des privilèges root

