#!/bin/bash

# Script d'installation des containers, réseaux et volumes Vocalyx
# Ce script installe tous les services définis dans le dossier services/

set -e  # Arrêter en cas d'erreur

SERVICES_DIR="$(dirname "$0")/services"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

# Couleurs pour les messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que le dossier services existe
if [ ! -d "$SERVICES_DIR" ]; then
    echo_error "Le dossier services n'existe pas: $SERVICES_DIR"
    exit 1
fi

echo_info "Début de l'installation des services Vocalyx..."

# 1. Créer le réseau
echo_info "Création du réseau..."
NETWORK_FILE="$SERVICES_DIR/vocalyx.network"
if [ -f "$NETWORK_FILE" ]; then
    NETWORK_NAME=$(grep "^NetworkName=" "$NETWORK_FILE" | cut -d'=' -f2)
    if [ -n "$NETWORK_NAME" ]; then
        if podman network exists "$NETWORK_NAME" 2>/dev/null; then
            echo_warn "Le réseau $NETWORK_NAME existe déjà"
        else
            SUBNET=$(grep "^Subnet=" "$NETWORK_FILE" | cut -d'=' -f2)
            GATEWAY=$(grep "^Gateway=" "$NETWORK_FILE" | cut -d'=' -f2)
            podman network create --subnet "$SUBNET" --gateway "$GATEWAY" "$NETWORK_NAME"
            echo_info "Réseau $NETWORK_NAME créé"
        fi
    fi
fi

# 2. Créer les volumes
echo_info "Création des volumes..."
for VOLUME_FILE in "$SERVICES_DIR"/*.volume; do
    if [ -f "$VOLUME_FILE" ]; then
        VOLUME_NAME=$(grep "^VolumeName=" "$VOLUME_FILE" | cut -d'=' -f2)
        if [ -n "$VOLUME_NAME" ]; then
            if podman volume exists "$VOLUME_NAME" 2>/dev/null; then
                echo_warn "Le volume $VOLUME_NAME existe déjà"
            else
                podman volume create "$VOLUME_NAME"
                echo_info "Volume $VOLUME_NAME créé"
            fi
        fi
    fi
done

# 3. Créer le répertoire systemd user si nécessaire
echo_info "Préparation des unit files systemd..."
mkdir -p "$SYSTEMD_USER_DIR"

# 4. Copier les unit files systemd (seulement les containers)
echo_info "Installation des unit files systemd..."
for UNIT_FILE in "$SERVICES_DIR"/*.container; do
    if [ -f "$UNIT_FILE" ]; then
        FILENAME=$(basename "$UNIT_FILE")
        cp "$UNIT_FILE" "$SYSTEMD_USER_DIR/$FILENAME"
        echo_info "Copié: $FILENAME"
    fi
done

# 5. Recharger systemd
echo_info "Rechargement de systemd..."
systemctl --user daemon-reload

# 6. Activer les services (sans les démarrer immédiatement)
echo_info "Activation des services..."
for UNIT_FILE in "$SERVICES_DIR"/*.container; do
    if [ -f "$UNIT_FILE" ]; then
        FILENAME=$(basename "$UNIT_FILE")
        SERVICE_NAME="${FILENAME%.container}"
        systemctl --user enable "$FILENAME" || echo_warn "Impossible d'activer $FILENAME"
    fi
done

# 7. Démarrer les services nécessaires pour l'initialisation
echo_info "Démarrage des services nécessaires..."
systemctl --user start vocalyx-postgres.container || echo_warn "Impossible de démarrer postgres"
systemctl --user start vocalyx-redis.container || echo_warn "Impossible de démarrer redis"

# Attendre que postgres soit prêt
echo_info "Attente que PostgreSQL soit prêt..."
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if podman exec vocalyx-postgres pg_isready -U vocalyx -d vocalyx_db >/dev/null 2>&1; then
        echo_info "PostgreSQL est prêt"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo_error "PostgreSQL n'est pas prêt après $MAX_RETRIES tentatives"
    exit 1
fi

# Démarrer l'API pour l'initialisation
echo_info "Démarrage de l'API pour l'initialisation..."
systemctl --user start vocalyx-api@01.container || echo_warn "Impossible de démarrer l'API"

# Attendre que l'API soit prête
echo_info "Attente que l'API soit prête..."
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if podman exec vocalyx-api-01 curl -f http://localhost:8000/health >/dev/null 2>&1; then
        echo_info "L'API est prête"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo_warn "L'API n'est pas prête, mais on continue quand même l'initialisation..."
fi

# 8. Initialiser la base de données
echo_info "Initialisation de la base de données..."
if podman exec vocalyx-api-01 python -c "from database import init_db; init_db()" 2>/dev/null; then
    echo_info "Base de données initialisée avec succès"
else
    echo_error "Erreur lors de l'initialisation de la base de données"
    exit 1
fi

# 9. Vérifier les tables
echo_info "Vérification des tables de la base de données..."
podman exec vocalyx-postgres psql -U vocalyx -d vocalyx_db -c "\dt"

echo_info "Installation terminée !"
echo ""
echo_warn "Pour démarrer les autres services, utilisez:"
echo "  systemctl --user start <service-name>.container"
echo ""
echo_warn "Pour voir le statut des services:"
echo "  systemctl --user status <service-name>.container"
