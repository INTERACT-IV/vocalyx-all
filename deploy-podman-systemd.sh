#!/bin/bash
# ============================================================================
# Script de déploiement Vocalyx avec Podman/systemd
# ============================================================================

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Obtenir le répertoire du projet (où se trouve ce script)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Déploiement Vocalyx avec Podman/systemd ===${NC}"
echo "Répertoire du projet: $PROJECT_DIR"
echo ""

# Vérifier que Podman est installé
if ! command -v podman &> /dev/null; then
    echo -e "${RED}Erreur: Podman n'est pas installé${NC}"
    exit 1
fi

# Vérifier que nous sommes root ou avec sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Note: Ce script nécessite des privilèges sudo${NC}"
    SUDO="sudo"
else
    SUDO=""
fi

# Étape 1: Construction des images
echo -e "${GREEN}[1/5] Construction des images...${NC}"
echo "  - API..."
podman build -t vocalyx-api:latest -f "$PROJECT_DIR/vocalyx-api/Containerfile" "$PROJECT_DIR/vocalyx-api" || {
    echo -e "${RED}Erreur lors de la construction de l'image API${NC}"
    exit 1
}

echo "  - Frontend..."
podman build -t vocalyx-frontend:latest -f "$PROJECT_DIR/vocalyx-frontend/Containerfile" "$PROJECT_DIR/vocalyx-frontend" || {
    echo -e "${RED}Erreur lors de la construction de l'image Frontend${NC}"
    exit 1
}

echo "  - Transcription Worker..."
podman build -t vocalyx-transcribe:latest -f "$PROJECT_DIR/vocalyx-transcribe/Containerfile" "$PROJECT_DIR/vocalyx-transcribe" || {
    echo -e "${RED}Erreur lors de la construction de l'image Transcription${NC}"
    exit 1
}

echo "  - Enrichment Worker..."
podman build -t vocalyx-enrichment:latest -f "$PROJECT_DIR/vocalyx-enrichment/Containerfile" "$PROJECT_DIR/vocalyx-enrichment" || {
    echo -e "${RED}Erreur lors de la construction de l'image Enrichment${NC}"
    exit 1
}

# Étape 2: Créer un répertoire temporaire pour les fichiers modifiés
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo -e "${GREEN}[2/5] Préparation des fichiers de configuration...${NC}"

# Copier et modifier les fichiers .container pour remplacer %E par le chemin du projet
for file in "$PROJECT_DIR"/*.container; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        # Remplacer %E par le chemin absolu du projet
        sed "s|%E|$PROJECT_DIR|g" "$file" > "$TMP_DIR/$filename"
        echo "  - $filename préparé"
    fi
done

# Copier les autres fichiers (.network, .volume) sans modification
for file in "$PROJECT_DIR"/*.network "$PROJECT_DIR"/*.volume; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        cp "$file" "$TMP_DIR/$filename"
        echo "  - $filename copié"
    fi
done

# Étape 3: Installation des fichiers systemd
echo -e "${GREEN}[3/5] Installation des fichiers systemd...${NC}"
$SUDO mkdir -p /etc/containers/systemd
$SUDO cp "$TMP_DIR"/*.{network,volume,container} /etc/containers/systemd/
echo "  Fichiers copiés dans /etc/containers/systemd/"

# Étape 4: Recharger systemd
echo -e "${GREEN}[4/5] Rechargement de systemd...${NC}"
$SUDO systemctl daemon-reload
echo "  systemd rechargé"

# Étape 5: Démarrage des services
echo -e "${GREEN}[5/5] Démarrage des services...${NC}"

# Infrastructure
echo "  - Infrastructure (réseau, volumes)..."
$SUDO systemctl start vocalyx-network.service || echo -e "${YELLOW}    Avertissement: réseau peut-être déjà créé${NC}"
$SUDO systemctl start vocalyx-postgres-data.service || echo -e "${YELLOW}    Avertissement: volume peut-être déjà créé${NC}"
$SUDO systemctl start vocalyx-redis-data.service || echo -e "${YELLOW}    Avertissement: volume peut-être déjà créé${NC}"

# Services de base
echo "  - Services de base (PostgreSQL, Redis)..."
$SUDO systemctl start vocalyx-postgres.service
$SUDO systemctl start vocalyx-redis.service
sleep 5

# Services API
echo "  - Services API..."
$SUDO systemctl start vocalyx-api-01.service
$SUDO systemctl start vocalyx-api-02.service
sleep 10

# HAProxy
echo "  - HAProxy..."
$SUDO systemctl start vocalyx-haproxy.service
sleep 5

# Frontend
echo "  - Frontend..."
$SUDO systemctl start vocalyx-frontend.service

# Workers
echo "  - Workers..."
$SUDO systemctl start vocalyx-transcribe-01.service
$SUDO systemctl start vocalyx-transcribe-02.service
$SUDO systemctl start vocalyx-transcribe-03.service
$SUDO systemctl start vocalyx-enrichment-01.service
$SUDO systemctl start vocalyx-enrichment-02.service

# Monitoring (optionnel)
echo "  - Monitoring (Flower)..."
$SUDO systemctl start vocalyx-flower.service || echo -e "${YELLOW}    Flower optionnel, peut être ignoré${NC}"

echo ""
echo -e "${GREEN}=== Déploiement terminé avec succès ! ===${NC}"
echo ""
echo "Vérifier le statut des services:"
echo "  sudo systemctl status 'vocalyx-*'"
echo ""
echo "Voir les logs:"
echo "  sudo journalctl -u vocalyx-api-01.service -f"
echo ""
echo "Activer le démarrage automatique:"
echo "  sudo systemctl enable 'vocalyx-*'"

