#!/bin/bash
# ============================================================================
# Script de déploiement Vocalyx avec Podman/systemd
# ============================================================================
# Usage:
#   ./deploy-podman-systemd.sh [options]
#
# Options:
#   --skip-build  : Sauter la construction des images (suppose qu'elles existent)
#   --user-mode   : Utiliser systemd en mode utilisateur
#   --user USER   : Utiliser un utilisateur spécifique (nécessite --user-mode, défaut: ai-user)
#   -h, --help    : Afficher cette aide
# ============================================================================

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
SKIP_BUILD=false
USER_MODE=false
TARGET_USER="ai-user"

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
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
            echo "  --skip-build    Sauter la construction des images"
            echo "  --user-mode     Utiliser systemd en mode utilisateur (défaut: mode système)"
            echo "  --user USER     Utiliser un utilisateur spécifique (nécessite --user-mode, défaut: ai-user)"
            echo "  -h, --help      Afficher cette aide"
            echo ""
            echo "Note: Pour construire les images séparément, utilisez:"
            echo "  ./build-images.sh"
            echo ""
            echo "Par défaut, le script utilise systemd en mode système (root)."
            echo "Utilisez --user-mode pour activer le mode utilisateur."
            exit 0
            ;;
        *)
            echo -e "${RED}Option inconnue: $1${NC}"
            echo "Utilisez --help pour voir les options disponibles"
            exit 1
            ;;
    esac
done

# Obtenir le répertoire du projet (où se trouve ce script)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration selon le mode
if [ "$USER_MODE" = true ]; then
    MODE_DESC="mode utilisateur"
    
    # Vérifier que l'utilisateur cible existe
    if ! id "$TARGET_USER" &>/dev/null; then
        echo -e "${RED}❌ Erreur: L'utilisateur '$TARGET_USER' n'existe pas${NC}"
        echo ""
        echo "Créer l'utilisateur avec:"
        echo "  sudo useradd -m -s /bin/bash $TARGET_USER"
        echo "  sudo loginctl enable-linger $TARGET_USER"
        exit 1
    fi
    
    # Obtenir le répertoire home de l'utilisateur cible
    TARGET_HOME=$(eval echo ~$TARGET_USER)
    SYSTEMD_DIR="$TARGET_HOME/.config/containers/systemd"
    SYSTEMCTL_CMD="sudo -u $TARGET_USER systemctl --user"
    PODMAN_CMD="sudo -u $TARGET_USER podman"
    
    # Vérifier que systemd --user est disponible
    if ! sudo -u "$TARGET_USER" systemctl --user --version &>/dev/null; then
        echo -e "${YELLOW}⚠ Avertissement: systemd --user peut ne pas être activé${NC}"
        echo "  Activer avec: sudo loginctl enable-linger $TARGET_USER"
        echo ""
    fi
else
    MODE_DESC="mode système"
    SYSTEMCTL_CMD="systemctl"
    SYSTEMD_DIR="/etc/containers/systemd"
    PODMAN_CMD="podman"
    
    # Vérifier que nous avons les privilèges root
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${YELLOW}Note: Ce script nécessite des privilèges sudo en mode système${NC}"
        SUDO="sudo"
    else
        SUDO=""
    fi
    SYSTEMCTL_CMD="$SUDO systemctl"
    PODMAN_CMD="$SUDO podman"
fi

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Déploiement Vocalyx avec Podman/systemd ($MODE_DESC)║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  - Répertoire du projet: $PROJECT_DIR"
echo "  - Mode: $MODE_DESC"
[ "$USER_MODE" = true ] && echo "  - Utilisateur: $TARGET_USER"
echo "  - Répertoire systemd: $SYSTEMD_DIR"
echo ""

# Vérifier que Podman est installé
if ! command -v podman &> /dev/null; then
    echo -e "${RED}❌ Erreur: Podman n'est pas installé${NC}"
    exit 1
fi

# Étape 1: Vérification/Construction des images
if [ "$SKIP_BUILD" = true ]; then
    echo -e "${GREEN}[1/5] Vérification des images (construction ignorée)...${NC}"
    echo "  Vérification que les images existent..."
    
    # Vérifier les images officielles
    OFFICIAL_IMAGES=("postgres:15-alpine" "redis:7-alpine" "haproxy:2.8-alpine" "mher/flower:2.0")
    MISSING_OFFICIAL=()
    for img in "${OFFICIAL_IMAGES[@]}"; do
        if ! $PODMAN_CMD image exists "$img" 2>/dev/null; then
            MISSING_OFFICIAL+=("$img")
        fi
    done
    
    if [ ${#MISSING_OFFICIAL[@]} -gt 0 ]; then
        echo -e "${YELLOW}  ⚠ Images officielles manquantes, téléchargement en cours...${NC}"
        for img in "${MISSING_OFFICIAL[@]}"; do
            echo "    - Téléchargement de $img..."
            $PODMAN_CMD pull "$img" || {
                echo -e "${RED}      ✗ Erreur lors du téléchargement de $img${NC}"
            }
        done
    else
        echo -e "${GREEN}  ✓ Toutes les images officielles sont présentes${NC}"
    fi
    
    # Vérifier les images Vocalyx
    MISSING_IMAGES=()
    for img in "vocalyx-api:latest" "vocalyx-frontend:latest" "vocalyx-transcribe:latest" "vocalyx-enrichment:latest"; do
        if ! $PODMAN_CMD image exists "$img" 2>/dev/null; then
            MISSING_IMAGES+=("$img")
        fi
    done
    
    if [ ${#MISSING_IMAGES[@]} -gt 0 ]; then
        echo -e "${RED}  ✗ Images Vocalyx manquantes:${NC}"
        for img in "${MISSING_IMAGES[@]}"; do
            echo -e "${RED}    - $img${NC}"
        done
        echo ""
        echo -e "${YELLOW}  Construisez les images avec: ./build-images.sh${NC}"
        exit 1
    else
        echo -e "${GREEN}  ✓ Toutes les images Vocalyx sont présentes${NC}"
    fi
else
    echo -e "${GREEN}[1/5] Vérification/Construction des images...${NC}"
    
    # Vérifier si le script de build existe
    BUILD_SCRIPT="$PROJECT_DIR/build-images.sh"
    if [ -f "$BUILD_SCRIPT" ]; then
        echo "  Script de build détecté: $BUILD_SCRIPT"
        echo "  Vérification des images existantes..."
        
        # Vérifier si toutes les images existent
        # D'abord les images officielles
        OFFICIAL_IMAGES=("postgres:15-alpine" "redis:7-alpine" "haproxy:2.8-alpine" "mher/flower:2.0")
        OFFICIAL_MISSING=false
        for img in "${OFFICIAL_IMAGES[@]}"; do
            if ! $PODMAN_CMD image exists "$img" 2>/dev/null; then
                OFFICIAL_MISSING=true
                break
            fi
        done
        
        # Ensuite les images Vocalyx
        IMAGES_EXIST=true
        for img in "vocalyx-api:latest" "vocalyx-frontend:latest" "vocalyx-transcribe:latest" "vocalyx-enrichment:latest"; do
            if ! $PODMAN_CMD image exists "$img" 2>/dev/null; then
                IMAGES_EXIST=false
                break
            fi
        done
        
        # Si des images officielles manquent, les télécharger
        if [ "$OFFICIAL_MISSING" = true ]; then
            echo -e "${YELLOW}  Certaines images officielles manquent. Téléchargement en cours...${NC}"
            for img in "${OFFICIAL_IMAGES[@]}"; do
                if ! $PODMAN_CMD image exists "$img" 2>/dev/null; then
                    echo "    - Téléchargement de $img..."
                    $PODMAN_CMD pull "$img" || {
                        echo -e "${YELLOW}      Avertissement: Erreur lors du téléchargement de $img (peut être ignoré pour flower)${NC}"
                    }
                fi
            done
        fi
        
        if [ "$IMAGES_EXIST" = false ]; then
            echo -e "${YELLOW}  Certaines images manquent. Construction en cours...${NC}"
            echo ""
            # Construire les images
            if [ "$USER_MODE" = true ]; then
                if ! sudo -u "$TARGET_USER" bash "$BUILD_SCRIPT"; then
                    echo -e "${RED}Erreur lors de la construction des images${NC}"
                    exit 1
                fi
            else
                if ! bash "$BUILD_SCRIPT"; then
                    echo -e "${RED}Erreur lors de la construction des images${NC}"
                    exit 1
                fi
            fi
        else
            echo -e "${GREEN}  ✓ Toutes les images sont déjà construites${NC}"
            echo "  Pour reconstruire, exécutez: ./build-images.sh"
        fi
    else
        echo -e "${YELLOW}  Script de build non trouvé. Construction directe...${NC}"
        echo "  - API..."
        $PODMAN_CMD build -t vocalyx-api:latest -f "$PROJECT_DIR/vocalyx-api/Containerfile" "$PROJECT_DIR/vocalyx-api" || {
            echo -e "${RED}Erreur lors de la construction de l'image API${NC}"
            exit 1
        }

        echo "  - Frontend..."
        $PODMAN_CMD build -t vocalyx-frontend:latest -f "$PROJECT_DIR/vocalyx-frontend/Containerfile" "$PROJECT_DIR/vocalyx-frontend" || {
            echo -e "${RED}Erreur lors de la construction de l'image Frontend${NC}"
            exit 1
        }

        echo "  - Transcription Worker..."
        $PODMAN_CMD build -t vocalyx-transcribe:latest -f "$PROJECT_DIR/vocalyx-transcribe/Containerfile" "$PROJECT_DIR/vocalyx-transcribe" || {
            echo -e "${RED}Erreur lors de la construction de l'image Transcription${NC}"
            exit 1
        }

        echo "  - Enrichment Worker..."
        $PODMAN_CMD build -t vocalyx-enrichment:latest -f "$PROJECT_DIR/vocalyx-enrichment/Containerfile" "$PROJECT_DIR/vocalyx-enrichment" || {
            echo -e "${RED}Erreur lors de la construction de l'image Enrichment${NC}"
            exit 1
        }
    fi
fi

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
echo -e "${GREEN}[3/5] Installation des fichiers systemd ($MODE_DESC)...${NC}"
if [ "$USER_MODE" = true ]; then
    sudo -u "$TARGET_USER" mkdir -p "$SYSTEMD_DIR"
    sudo -u "$TARGET_USER" cp "$TMP_DIR"/*.{network,volume,container} "$SYSTEMD_DIR/"
else
    $SUDO mkdir -p "$SYSTEMD_DIR"
    $SUDO cp "$TMP_DIR"/*.{network,volume,container} "$SYSTEMD_DIR/"
fi
echo "  Fichiers copiés dans $SYSTEMD_DIR/"

# Étape 4: Recharger systemd
echo -e "${GREEN}[4/5] Rechargement de systemd ($MODE_DESC)...${NC}"
if [ "$USER_MODE" = true ]; then
    sudo -u "$TARGET_USER" systemctl --user daemon-reload
    echo "  systemd --user rechargé"
else
    $SUDO systemctl daemon-reload
    echo "  systemd rechargé"
fi

# Étape 5: Démarrage des services
echo -e "${GREEN}[5/5] Démarrage des services ($MODE_DESC)...${NC}"
echo ""

# Infrastructure (réseau et volumes)
echo -e "${BLUE}1. Infrastructure (réseau, volumes)...${NC}"
$SYSTEMCTL_CMD start vocalyx-network.service || echo -e "${YELLOW}    Avertissement: réseau peut-être déjà créé${NC}"
$SYSTEMCTL_CMD start vocalyx-postgres-data.service || echo -e "${YELLOW}    Avertissement: volume peut-être déjà créé${NC}"
$SYSTEMCTL_CMD start vocalyx-redis-data.service || echo -e "${YELLOW}    Avertissement: volume peut-être déjà créé${NC}"
echo ""

# Services de base (PostgreSQL et Redis)
echo -e "${BLUE}2. Services de base (PostgreSQL, Redis)...${NC}"
$SYSTEMCTL_CMD start vocalyx-postgres.service
$SYSTEMCTL_CMD start vocalyx-redis.service
echo -e "${GREEN}  ✓ PostgreSQL démarré${NC}"
echo -e "${GREEN}  ✓ Redis démarré${NC}"
sleep 5
echo ""

# Services API
echo -e "${BLUE}3. Services API...${NC}"
$SYSTEMCTL_CMD start vocalyx-api-01.service
$SYSTEMCTL_CMD start vocalyx-api-02.service
echo -e "${GREEN}  ✓ API-01 démarré${NC}"
echo -e "${GREEN}  ✓ API-02 démarré${NC}"
sleep 10
echo ""

# HAProxy (Load Balancer)
echo -e "${BLUE}4. HAProxy (Load Balancer)...${NC}"
$SYSTEMCTL_CMD start vocalyx-haproxy.service
echo -e "${GREEN}  ✓ HAProxy démarré${NC}"
sleep 5
echo ""

# Frontend
echo -e "${BLUE}5. Frontend...${NC}"
$SYSTEMCTL_CMD start vocalyx-frontend.service
echo -e "${GREEN}  ✓ Frontend démarré${NC}"
echo ""

# Workers
echo -e "${BLUE}6. Workers de transcription...${NC}"
$SYSTEMCTL_CMD start vocalyx-transcribe-01.service
$SYSTEMCTL_CMD start vocalyx-transcribe-02.service
$SYSTEMCTL_CMD start vocalyx-transcribe-03.service
echo -e "${GREEN}  ✓ Transcribe-01 démarré${NC}"
echo -e "${GREEN}  ✓ Transcribe-02 démarré${NC}"
echo -e "${GREEN}  ✓ Transcribe-03 démarré${NC}"
echo ""

echo -e "${BLUE}7. Workers d'enrichissement...${NC}"
$SYSTEMCTL_CMD start vocalyx-enrichment-01.service
$SYSTEMCTL_CMD start vocalyx-enrichment-02.service
echo -e "${GREEN}  ✓ Enrichment-01 démarré${NC}"
echo -e "${GREEN}  ✓ Enrichment-02 démarré${NC}"
echo ""

# Monitoring (optionnel)
echo -e "${BLUE}8. Monitoring (Flower - optionnel)...${NC}"
$SYSTEMCTL_CMD start vocalyx-flower.service && echo -e "${GREEN}  ✓ Flower démarré${NC}" || echo -e "${YELLOW}  ⚠ Flower optionnel, peut être ignoré${NC}"
echo ""

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Déploiement terminé avec succès !                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Commandes utiles ($MODE_DESC):${NC}"
echo ""

if [ "$USER_MODE" = true ]; then
    echo "Vérifier le statut des services:"
    echo "  sudo -u $TARGET_USER systemctl --user status 'vocalyx-*'"
    echo ""
    echo "Voir les logs:"
    echo "  sudo -u $TARGET_USER journalctl --user -u vocalyx-api-01.service -f"
    echo ""
    echo "Activer le démarrage automatique:"
    echo "  sudo -u $TARGET_USER systemctl --user enable 'vocalyx-*'"
    echo ""
    echo "Arrêter un service:"
    echo "  sudo -u $TARGET_USER systemctl --user stop vocalyx-api-01.service"
    echo ""
    echo "Redémarrer un service:"
    echo "  sudo -u $TARGET_USER systemctl --user restart vocalyx-api-01.service"
    echo ""
    echo -e "${YELLOW}Note:${NC} Les services s'exécutent en mode utilisateur pour $TARGET_USER"
    echo "  Les conteneurs sont gérés par Podman rootless"
else
    echo "Vérifier le statut des services:"
    echo "  $SUDO systemctl status 'vocalyx-*'"
    echo ""
    echo "Voir les logs:"
    echo "  $SUDO journalctl -u vocalyx-api-01.service -f"
    echo ""
    echo "Activer le démarrage automatique:"
    echo "  $SUDO systemctl enable 'vocalyx-*'"
    echo ""
    echo "Arrêter un service:"
    echo "  $SUDO systemctl stop vocalyx-api-01.service"
    echo ""
    echo "Redémarrer un service:"
    echo "  $SUDO systemctl restart vocalyx-api-01.service"
    echo ""
    echo -e "${YELLOW}Note:${NC} Les services s'exécutent en mode système (root)"
    echo "  Les conteneurs sont gérés par Podman en mode root"
fi

