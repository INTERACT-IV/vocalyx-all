#!/bin/bash
# ============================================================================
# Script pour installer les fichiers quadlet dans systemd
# ============================================================================
# Usage:
#   ./install-quadlet-files.sh [--user-mode] [--user USER]
# ============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
USER_MODE=false
TARGET_USER="ai-user"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
            echo "  --user-mode     Utiliser systemd en mode utilisateur"
            echo "  --user USER      Utiliser un utilisateur spécifique (nécessite --user-mode, défaut: ai-user)"
            echo "  -h, --help       Afficher cette aide"
            exit 0
            ;;
        *)
            echo -e "${RED}Option inconnue: $1${NC}"
            exit 1
            ;;
    esac
done

# Configuration selon le mode
if [ "$USER_MODE" = true ]; then
    TARGET_HOME=$(eval echo ~$TARGET_USER)
    SYSTEMD_DIR="$TARGET_HOME/.config/containers/systemd"
    SYSTEMCTL_CMD="sudo -u $TARGET_USER systemctl --user"
    PODMAN_CMD="sudo -u $TARGET_USER podman"
    MODE_DESC="mode utilisateur"
else
    SYSTEMD_DIR="/etc/containers/systemd"
    SYSTEMCTL_CMD="sudo systemctl"
    PODMAN_CMD="sudo podman"
    MODE_DESC="mode système"
    if [ "$EUID" -ne 0 ]; then 
        SUDO="sudo"
    else
        SUDO=""
    fi
    SYSTEMCTL_CMD="$SUDO systemctl"
    PODMAN_CMD="$SUDO podman"
fi

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Installation des fichiers quadlet systemd                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  - Répertoire du projet: $PROJECT_DIR"
echo "  - Mode: $MODE_DESC"
[ "$USER_MODE" = true ] && echo "  - Utilisateur: $TARGET_USER"
echo "  - Répertoire systemd: $SYSTEMD_DIR"
echo ""

# Créer le répertoire systemd
echo -e "${BLUE}[1/3] Création du répertoire systemd...${NC}"
if [ "$USER_MODE" = true ]; then
    sudo -u "$TARGET_USER" mkdir -p "$SYSTEMD_DIR"
else
    $SUDO mkdir -p "$SYSTEMD_DIR"
fi
echo -e "${GREEN}  ✓ Répertoire créé${NC}"
echo ""

# Créer un répertoire temporaire pour les fichiers modifiés
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Préparer les fichiers
echo -e "${BLUE}[2/3] Préparation des fichiers...${NC}"

# Copier et modifier les fichiers .container pour remplacer %E
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

echo ""

# Installer les fichiers
echo -e "${BLUE}[3/3] Installation des fichiers dans $SYSTEMD_DIR...${NC}"
if [ "$USER_MODE" = true ]; then
    sudo -u "$TARGET_USER" cp "$TMP_DIR"/*.{network,volume,container} "$SYSTEMD_DIR/" 2>/dev/null || {
        echo -e "${RED}  ✗ Erreur lors de la copie${NC}"
        exit 1
    }
else
    $SUDO cp "$TMP_DIR"/*.{network,volume,container} "$SYSTEMD_DIR/" 2>/dev/null || {
        echo -e "${RED}  ✗ Erreur lors de la copie${NC}"
        exit 1
    }
fi

# Compter les fichiers installés
if [ "$USER_MODE" = true ]; then
    COUNT=$(sudo -u "$TARGET_USER" ls -1 "$SYSTEMD_DIR"/*.{network,volume,container} 2>/dev/null | wc -l)
else
    COUNT=$($SUDO ls -1 "$SYSTEMD_DIR"/*.{network,volume,container} 2>/dev/null | wc -l)
fi

echo -e "${GREEN}  ✓ $COUNT fichiers installés${NC}"
echo ""

# Recharger systemd
echo -e "${BLUE}Rechargement de systemd...${NC}"
if [ "$USER_MODE" = true ]; then
    sudo -u "$TARGET_USER" systemctl --user daemon-reload
else
    $SUDO systemctl daemon-reload
fi
echo -e "${GREEN}  ✓ systemd rechargé${NC}"
echo ""

# Vérifier les services générés
echo -e "${BLUE}Vérification des services générés...${NC}"
if [ "$USER_MODE" = true ]; then
    SERVICES=$(sudo -u "$TARGET_USER" systemctl --user list-unit-files 'vocalyx-*.service' 2>/dev/null | grep -v "UNIT FILE" | grep -v "^$" | awk '{print $1}' || echo "")
else
    SERVICES=$($SUDO systemctl list-unit-files 'vocalyx-*.service' 2>/dev/null | grep -v "UNIT FILE" | grep -v "^$" | awk '{print $1}' || echo "")
fi

if [ -z "$SERVICES" ]; then
    echo -e "${YELLOW}  ⚠ Aucun service trouvé (peut prendre quelques secondes)${NC}"
else
    COUNT_SERVICES=$(echo "$SERVICES" | wc -l)
    echo -e "${GREEN}  ✓ $COUNT_SERVICES services trouvés${NC}"
    echo ""
    echo "Services disponibles:"
    echo "$SERVICES" | head -10 | while read service; do
        echo "  - $service"
    done
    [ $(echo "$SERVICES" | wc -l) -gt 10 ] && echo "  ... et plus"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Installation terminée avec succès !                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Commandes utiles:${NC}"
echo ""
if [ "$USER_MODE" = true ]; then
    echo "Vérifier les services:"
    echo "  sudo -u $TARGET_USER systemctl --user list-unit-files 'vocalyx-*.service'"
    echo ""
    echo "Démarrer un service:"
    echo "  sudo -u $TARGET_USER systemctl --user start vocalyx-transcribe-01.service"
    echo ""
    echo "Voir les logs:"
    echo "  sudo -u $TARGET_USER journalctl --user -u vocalyx-transcribe-01.service -f"
else
    echo "Vérifier les services:"
    echo "  $SUDO systemctl list-unit-files 'vocalyx-*.service'"
    echo ""
    echo "Démarrer un service:"
    echo "  $SUDO systemctl start vocalyx-transcribe-01.service"
    echo ""
    echo "Voir les logs:"
    echo "  $SUDO journalctl -u vocalyx-transcribe-01.service -f"
fi
echo ""

