#!/bin/bash
# ============================================================================
# Script d'initialisation de la base de données Vocalyx avec Podman/systemd
# ============================================================================
# Usage:
#   ./init-db-podman.sh [--user-mode] [--user USER]
#
# Options:
#   --user-mode   : Utiliser Podman en mode utilisateur (rootless)
#   --user USER   : Utiliser un utilisateur spécifique (nécessite --user-mode, défaut: ai-user)
# ============================================================================

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
USER_MODE=false
TARGET_USER="ai-user"
PODMAN_CMD="podman"
API_CONTAINER="vocalyx-api-01"
POSTGRES_CONTAINER="vocalyx-postgres"

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --user-mode)
            USER_MODE=true
            shift
            ;;
        --user)
            if [ "$USER_MODE" != true ]; then
                echo -e "${RED}Erreur: --user nécessite --user-mode${NC}"
                exit 1
            fi
            TARGET_USER="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --user-mode     Utiliser Podman en mode utilisateur (défaut: mode système)"
            echo "  --user USER      Utiliser un utilisateur spécifique (nécessite --user-mode, défaut: ai-user)"
            echo "  -h, --help       Afficher cette aide"
            exit 0
            ;;
        *)
            echo -e "${RED}Option inconnue: $1${NC}"
            echo "Utilisez --help pour voir les options disponibles"
            exit 1
            ;;
    esac
done

# Configuration selon le mode
if [ "$USER_MODE" = true ]; then
    PODMAN_CMD="sudo -u $TARGET_USER podman"
    echo -e "${BLUE}Mode: utilisateur ($TARGET_USER)${NC}"
else
    if [ "$EUID" -ne 0 ]; then 
        SUDO="sudo"
    else
        SUDO=""
    fi
    PODMAN_CMD="$SUDO podman"
    echo -e "${BLUE}Mode: système${NC}"
fi

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Initialisation de la base de données Vocalyx              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Vérifier que Podman est installé
if ! command -v podman &> /dev/null; then
    echo -e "${RED}❌ Erreur: Podman n'est pas installé${NC}"
    exit 1
fi

# Vérifier que le conteneur API existe
echo -e "${BLUE}[1/4] Vérification des conteneurs...${NC}"
if ! $PODMAN_CMD container exists "$API_CONTAINER" 2>/dev/null; then
    echo -e "${RED}❌ Erreur: Le conteneur '$API_CONTAINER' n'existe pas${NC}"
    echo ""
    echo "Vérifiez que les services sont démarrés:"
    if [ "$USER_MODE" = true ]; then
        echo "  sudo -u $TARGET_USER systemctl --user status vocalyx-api-01.service"
    else
        echo "  sudo systemctl status vocalyx-api-01.service"
    fi
    exit 1
fi

if ! $PODMAN_CMD container exists "$POSTGRES_CONTAINER" 2>/dev/null; then
    echo -e "${RED}❌ Erreur: Le conteneur '$POSTGRES_CONTAINER' n'existe pas${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ Conteneurs trouvés${NC}"
echo ""

# Vérifier que PostgreSQL est prêt
echo -e "${BLUE}[2/4] Vérification de PostgreSQL...${NC}"
echo "  Attente que PostgreSQL soit prêt..."
for i in {1..30}; do
    if $PODMAN_CMD exec "$POSTGRES_CONTAINER" pg_isready -U vocalyx -d vocalyx_db >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ PostgreSQL est prêt${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}  ✗ PostgreSQL n'est pas prêt après 30 tentatives${NC}"
        exit 1
    fi
    sleep 1
done
echo ""

# Vérifier que l'API est accessible
echo -e "${BLUE}[3/4] Vérification de l'API...${NC}"
echo "  Attente que l'API soit prête..."
for i in {1..30}; do
    # Vérifier si le conteneur API répond
    if $PODMAN_CMD exec "$API_CONTAINER" curl -f -s http://localhost:8000/health >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ API est prête${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${YELLOW}  ⚠ L'API n'est pas encore accessible, mais on continue...${NC}"
        break
    fi
    sleep 2
done
echo ""

# Initialiser la base de données
echo -e "${BLUE}[4/4] Initialisation de la base de données...${NC}"
echo "  Exécution de init_db() dans le conteneur API..."

if $PODMAN_CMD exec "$API_CONTAINER" python -c "from database import init_db; init_db()" 2>&1; then
    echo ""
    echo -e "${GREEN}  ✓ Base de données initialisée avec succès${NC}"
    echo ""
    
    # Afficher les tables créées
    echo -e "${BLUE}Vérification des tables créées...${NC}"
    $PODMAN_CMD exec "$POSTGRES_CONTAINER" psql -U vocalyx -d vocalyx_db -c "\dt" || true
    echo ""
    
    # Afficher les informations importantes
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Initialisation terminée avec succès !                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} Vérifiez les logs du conteneur API pour voir la clé API admin:"
    if [ "$USER_MODE" = true ]; then
        echo "  sudo -u $TARGET_USER podman logs $API_CONTAINER | grep 'Clé API Admin'"
    else
        echo "  $PODMAN_CMD logs $API_CONTAINER | grep 'Clé API Admin'"
    fi
    echo ""
else
    echo ""
    echo -e "${RED}  ✗ Erreur lors de l'initialisation${NC}"
    echo ""
    echo -e "${BLUE}Vérification de l'état de la base de données...${NC}"
    $PODMAN_CMD exec "$POSTGRES_CONTAINER" psql -U vocalyx -d vocalyx_db -c "\dt" || true
    echo ""
    echo -e "${YELLOW}Note:${NC} La base de données pourrait déjà être initialisée."
    echo "  Vérifiez les logs pour plus d'informations:"
    if [ "$USER_MODE" = true ]; then
        echo "  sudo -u $TARGET_USER podman logs $API_CONTAINER"
    else
        echo "  $PODMAN_CMD logs $API_CONTAINER"
    fi
    exit 1
fi

