#!/bin/bash
# ============================================================================
# Script d'installation des fichiers .service systemd pour Vocalyx
# ============================================================================
# Ce script installe tous les fichiers .service dans /etc/systemd/system/
# et configure le chemin du projet.
#
# Usage:
#   ./install-services.sh [PROJECT_DIR]
#
# Exemple:
#   ./install-services.sh /home/user/code/vocalyx-all
# ============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Obtenir le répertoire du projet
if [ -n "$1" ]; then
    PROJECT_DIR="$1"
else
    # Essayer de détecter automatiquement
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$SCRIPT_DIR"
fi

# Vérifier que le répertoire existe
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Erreur: Le répertoire '$PROJECT_DIR' n'existe pas${NC}"
    exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Installation des fichiers .service systemd pour Vocalyx ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  - Répertoire du projet: $PROJECT_DIR"
echo "  - Destination: /etc/systemd/system/"
echo ""

# Vérifier les privilèges
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Note: Ce script nécessite des privilèges sudo${NC}"
    SUDO="sudo"
else
    SUDO=""
fi

# Créer un répertoire temporaire
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo -e "${GREEN}[1/2] Préparation des fichiers .service...${NC}"

# Liste des fichiers .service
SERVICE_FILES=(
    "vocalyx-postgres.service"
    "vocalyx-redis.service"
    "vocalyx-haproxy.service"
    "vocalyx-api-01.service"
    "vocalyx-api-02.service"
    "vocalyx-frontend.service"
    "vocalyx-transcribe-01.service"
    "vocalyx-transcribe-02.service"
    "vocalyx-transcribe-03.service"
    "vocalyx-enrichment-01.service"
    "vocalyx-enrichment-02.service"
    "vocalyx-flower.service"
)

# Copier et modifier les fichiers qui nécessitent PROJECT_DIR
for file in "${SERVICE_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Remplacer PROJECT_DIR dans les fichiers qui en ont besoin
        if grep -q "PROJECT_DIR" "$file" 2>/dev/null; then
            sed "s|PROJECT_DIR=/home/shinohk/code/vocalyx-all|PROJECT_DIR=$PROJECT_DIR|g" "$file" > "$TMP_DIR/$file"
            echo "  ✓ $file (PROJECT_DIR configuré)"
        else
            cp "$file" "$TMP_DIR/$file"
            echo "  ✓ $file"
        fi
    else
        echo -e "${YELLOW}  ⚠ $file non trouvé${NC}"
    fi
done

echo ""
echo -e "${GREEN}[2/2] Installation dans /etc/systemd/system/...${NC}"

# Copier les fichiers
$SUDO cp "$TMP_DIR"/*.service /etc/systemd/system/
echo -e "${GREEN}  ✓ Fichiers copiés${NC}"

# Recharger systemd
echo ""
echo -e "${GREEN}Rechargement de systemd...${NC}"
$SUDO systemctl daemon-reload
echo -e "${GREEN}  ✓ systemd rechargé${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Installation terminée avec succès !               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Commandes utiles:${NC}"
echo ""
echo "Démarrer tous les services:"
echo "  sudo systemctl start vocalyx-postgres.service"
echo "  sudo systemctl start vocalyx-redis.service"
echo "  # ... etc"
echo ""
echo "Activer le démarrage automatique:"
echo "  sudo systemctl enable vocalyx-postgres.service"
echo "  sudo systemctl enable vocalyx-redis.service"
echo "  # ... etc"
echo ""
echo "Voir le statut:"
echo "  sudo systemctl status vocalyx-postgres.service"
echo ""
echo "Voir les logs:"
echo "  sudo journalctl -u vocalyx-postgres.service -f"

