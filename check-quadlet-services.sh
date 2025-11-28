#!/bin/bash
# ============================================================================
# Script de diagnostic pour vérifier les services quadlet systemd
# ============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Diagnostic des services quadlet systemd                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Détecter le mode (utilisateur ou système)
USER_MODE=false
TARGET_USER="ai-user"

# Vérifier si on est en mode utilisateur
if [ -d "$HOME/.config/containers/systemd" ] && [ -n "$(ls -A $HOME/.config/containers/systemd/*.container 2>/dev/null)" ]; then
    USER_MODE=true
    SYSTEMD_DIR="$HOME/.config/containers/systemd"
    SYSTEMCTL_CMD="systemctl --user"
    echo -e "${GREEN}Mode détecté: Utilisateur${NC}"
    echo "  Répertoire: $SYSTEMD_DIR"
elif [ -d "/etc/containers/systemd" ] && [ -n "$(sudo ls -A /etc/containers/systemd/*.container 2>/dev/null)" ]; then
    SYSTEMD_DIR="/etc/containers/systemd"
    SYSTEMCTL_CMD="sudo systemctl"
    echo -e "${GREEN}Mode détecté: Système${NC}"
    echo "  Répertoire: $SYSTEMD_DIR"
else
    echo -e "${RED}❌ Aucun répertoire systemd trouvé${NC}"
    echo ""
    echo "Vérification des répertoires possibles:"
    echo "  Mode utilisateur: $HOME/.config/containers/systemd"
    echo "  Mode système: /etc/containers/systemd"
    exit 1
fi

echo ""

# 1. Vérifier les fichiers .container installés
echo -e "${BLUE}[1/5] Fichiers .container installés:${NC}"
if [ "$USER_MODE" = true ]; then
    CONTAINER_FILES=$(ls -1 "$SYSTEMD_DIR"/*.container 2>/dev/null || echo "")
else
    CONTAINER_FILES=$(sudo ls -1 "$SYSTEMD_DIR"/*.container 2>/dev/null || echo "")
fi

if [ -z "$CONTAINER_FILES" ]; then
    echo -e "${RED}  ✗ Aucun fichier .container trouvé${NC}"
    echo ""
    echo "  Les fichiers doivent être installés avec:"
    echo "    ./deploy-podman-systemd.sh"
    exit 1
else
    echo "$CONTAINER_FILES" | while read file; do
        filename=$(basename "$file")
        echo -e "${GREEN}  ✓ $filename${NC}"
    done
fi

# Vérifier spécifiquement les fichiers transcribe
echo ""
echo -e "${BLUE}  Fichiers transcribe spécifiquement:${NC}"
TRANSCRIBE_FILES=$(echo "$CONTAINER_FILES" | grep transcribe || echo "")
if [ -z "$TRANSCRIBE_FILES" ]; then
    echo -e "${RED}  ✗ Aucun fichier vocalyx-transcribe-*.container trouvé${NC}"
    echo ""
    echo "  Les fichiers doivent être copiés dans: $SYSTEMD_DIR"
else
    echo "$TRANSCRIBE_FILES" | while read file; do
        filename=$(basename "$file")
        echo -e "${GREEN}  ✓ $filename${NC}"
    done
fi

echo ""

# 2. Vérifier la syntaxe des fichiers
echo -e "${BLUE}[2/5] Vérification de la syntaxe des fichiers transcribe:${NC}"
for file in $TRANSCRIBE_FILES; do
    filename=$(basename "$file")
    echo -n "  Vérification de $filename... "
    
    # Vérifier que le fichier contient les sections requises
    if [ "$USER_MODE" = true ]; then
        HAS_UNIT=$(grep -c "^\[Unit\]" "$file" 2>/dev/null || echo "0")
        HAS_CONTAINER=$(grep -c "^\[Container\]" "$file" 2>/dev/null || echo "0")
        HAS_SERVICE=$(grep -c "^\[Service\]" "$file" 2>/dev/null || echo "0")
    else
        HAS_UNIT=$(sudo grep -c "^\[Unit\]" "$file" 2>/dev/null || echo "0")
        HAS_CONTAINER=$(sudo grep -c "^\[Container\]" "$file" 2>/dev/null || echo "0")
        HAS_SERVICE=$(sudo grep -c "^\[Service\]" "$file" 2>/dev/null || echo "0")
    fi
    
    if [ "$HAS_UNIT" -gt 0 ] && [ "$HAS_CONTAINER" -gt 0 ] && [ "$HAS_SERVICE" -gt 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo "    Sections trouvées: Unit=$HAS_UNIT, Container=$HAS_CONTAINER, Service=$HAS_SERVICE"
    fi
done

echo ""

# 3. Vérifier les services générés
echo -e "${BLUE}[3/5] Services systemd générés:${NC}"
if [ "$USER_MODE" = true ]; then
    SERVICES=$(systemctl --user list-unit-files 'vocalyx-transcribe-*.service' 2>/dev/null | grep -v "UNIT FILE" | grep -v "^$" | awk '{print $1}' || echo "")
else
    SERVICES=$(sudo systemctl list-unit-files 'vocalyx-transcribe-*.service' 2>/dev/null | grep -v "UNIT FILE" | grep -v "^$" | awk '{print $1}' || echo "")
fi

if [ -z "$SERVICES" ]; then
    echo -e "${RED}  ✗ Aucun service vocalyx-transcribe-*.service trouvé${NC}"
    echo ""
    echo -e "${YELLOW}  Solution:${NC}"
    echo "    1. Vérifiez que les fichiers sont dans: $SYSTEMD_DIR"
    echo "    2. Rechargez systemd: $SYSTEMCTL_CMD daemon-reload"
    echo "    3. Vérifiez les logs: journalctl -u systemd-*.service"
else
    echo "$SERVICES" | while read service; do
        echo -e "${GREEN}  ✓ $service${NC}"
    done
fi

echo ""

# 4. Vérifier si systemd a été rechargé
echo -e "${BLUE}[4/5] Vérification du rechargement systemd:${NC}"
echo "  Les services quadlet sont générés automatiquement lors du daemon-reload"
echo "  Si les services n'apparaissent pas, exécutez:"
if [ "$USER_MODE" = true ]; then
    echo -e "${YELLOW}    systemctl --user daemon-reload${NC}"
else
    echo -e "${YELLOW}    sudo systemctl daemon-reload${NC}"
fi

echo ""

# 5. Vérifier les erreurs dans les logs
echo -e "${BLUE}[5/5] Vérification des erreurs systemd:${NC}"
if [ "$USER_MODE" = true ]; then
    ERRORS=$(journalctl --user -u systemd-*.service --since "1 hour ago" --no-pager 2>/dev/null | grep -i "error\|fail" | tail -5 || echo "")
else
    ERRORS=$(sudo journalctl -u systemd-*.service --since "1 hour ago" --no-pager 2>/dev/null | grep -i "error\|fail" | tail -5 || echo "")
fi

if [ -z "$ERRORS" ]; then
    echo -e "${GREEN}  ✓ Aucune erreur récente trouvée${NC}"
else
    echo -e "${RED}  ✗ Erreurs trouvées:${NC}"
    echo "$ERRORS" | while read error; do
        echo "    $error"
    done
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Actions recommandées                                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -z "$TRANSCRIBE_FILES" ]; then
    echo -e "${YELLOW}1. Installer les fichiers .container:${NC}"
    echo "   ./deploy-podman-systemd.sh --skip-build"
    echo ""
fi

if [ -z "$SERVICES" ]; then
    echo -e "${YELLOW}2. Recharger systemd:${NC}"
    if [ "$USER_MODE" = true ]; then
        echo "   systemctl --user daemon-reload"
    else
        echo "   sudo systemctl daemon-reload"
    fi
    echo ""
fi

echo -e "${YELLOW}3. Vérifier les services après rechargement:${NC}"
if [ "$USER_MODE" = true ]; then
    echo "   systemctl --user list-unit-files 'vocalyx-transcribe-*.service'"
else
    echo "   sudo systemctl list-unit-files 'vocalyx-transcribe-*.service'"
fi
echo ""

