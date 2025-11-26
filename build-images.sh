#!/bin/bash
# ============================================================================
# Script de construction des images Vocalyx pour Podman
# ============================================================================
# Ce script construit toutes les images nécessaires pour le déploiement
# avec Podman/systemd.
#
# Usage:
#   ./build-images.sh [options]
#
# Options:
#   --no-cache    : Construire sans utiliser le cache
#   --push        : Pousser les images vers un registry (nécessite configuration)
#   --tag TAG     : Utiliser un tag personnalisé (défaut: latest)
# ============================================================================

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables par défaut
NO_CACHE=""
PUSH_IMAGES=false
IMAGE_TAG="latest"
REGISTRY=""

# Obtenir le répertoire du projet (où se trouve ce script)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --push)
            PUSH_IMAGES=true
            shift
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --no-cache       Construire sans utiliser le cache"
            echo "  --push           Pousser les images vers un registry"
            echo "  --tag TAG        Utiliser un tag personnalisé (défaut: latest)"
            echo "  --registry URL    URL du registry pour --push"
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

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Construction des images Vocalyx pour Podman            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  - Répertoire du projet: $PROJECT_DIR"
echo "  - Tag des images: $IMAGE_TAG"
echo "  - Cache: $([ -z "$NO_CACHE" ] && echo "activé" || echo "désactivé")"
echo "  - Push vers registry: $([ "$PUSH_IMAGES" = true ] && echo "oui" || echo "non")"
[ -n "$REGISTRY" ] && echo "  - Registry: $REGISTRY"
echo ""

# Vérifier que Podman est installé
if ! command -v podman &> /dev/null; then
    echo -e "${RED}❌ Erreur: Podman n'est pas installé${NC}"
    echo "   Installez Podman pour continuer."
    exit 1
fi

echo -e "${GREEN}✓ Podman détecté: $(podman --version)${NC}"
echo ""

# Fonction pour puller une image officielle
pull_image() {
    local image_name=$1
    local description=$2
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📥 Téléchargement: $image_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  Description: $description"
    echo ""
    
    local start_time=$(date +%s)
    
    if podman pull "$image_name"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓ Image téléchargée avec succès en ${duration}s${NC}"
        
        # Afficher la taille de l'image
        local image_size=$(podman images "$image_name" --format "{{.Size}}" | head -n1)
        echo -e "${GREEN}  Taille: $image_size${NC}"
        echo ""
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}✗ Erreur lors du téléchargement (${duration}s)${NC}"
        echo ""
        return 1
    fi
}

# Fonction pour construire une image
build_image() {
    local service_name=$1
    local context_path=$2
    local containerfile=$3
    local image_name="vocalyx-${service_name}:${IMAGE_TAG}"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📦 Construction: $image_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  Context: $context_path"
    echo "  Containerfile: $containerfile"
    echo ""
    
    local start_time=$(date +%s)
    
    if podman build $NO_CACHE \
        -t "$image_name" \
        -f "$PROJECT_DIR/$containerfile" \
        "$PROJECT_DIR/$context_path"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓ Image construite avec succès en ${duration}s${NC}"
        
        # Afficher la taille de l'image
        local image_size=$(podman images "$image_name" --format "{{.Size}}" | head -n1)
        echo -e "${GREEN}  Taille: $image_size${NC}"
        
        # Push si demandé
        if [ "$PUSH_IMAGES" = true ]; then
            local push_name="$image_name"
            if [ -n "$REGISTRY" ]; then
                push_name="${REGISTRY}/${image_name}"
                podman tag "$image_name" "$push_name"
            fi
            echo -e "${YELLOW}  Poussage vers registry...${NC}"
            if podman push "$push_name"; then
                echo -e "${GREEN}✓ Image poussée avec succès${NC}"
            else
                echo -e "${RED}✗ Erreur lors du push${NC}"
                return 1
            fi
        fi
        
        echo ""
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}✗ Erreur lors de la construction (${duration}s)${NC}"
        echo ""
        return 1
    fi
}

# Compteur d'erreurs
ERRORS=0
START_TIME=$(date +%s)

# Étape 1: Télécharger les images officielles (prérequis)
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}ÉTAPE 1: Téléchargement des images officielles${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}[1/4] Téléchargement de PostgreSQL...${NC}"
if ! pull_image "postgres:15-alpine" "Base de données PostgreSQL"; then
    ((ERRORS++))
fi

echo -e "${GREEN}[2/4] Téléchargement de Redis...${NC}"
if ! pull_image "redis:7-alpine" "Broker Redis et cache"; then
    ((ERRORS++))
fi

echo -e "${GREEN}[3/4] Téléchargement de HAProxy...${NC}"
if ! pull_image "haproxy:2.8-alpine" "Load balancer et reverse proxy"; then
    ((ERRORS++))
fi

echo -e "${GREEN}[4/4] Téléchargement de Flower...${NC}"
if ! pull_image "mher/flower:2.0" "Monitoring Celery (optionnel)"; then
    echo -e "${YELLOW}  Avertissement: Flower est optionnel, peut être ignoré${NC}"
    # Ne pas compter comme erreur car c'est optionnel
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}ÉTAPE 2: Construction des images Vocalyx${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Étape 2: Construction des images Vocalyx
echo -e "${GREEN}[1/4] Construction de l'image API...${NC}"
if ! build_image "api" "vocalyx-api" "vocalyx-api/Containerfile"; then
    ((ERRORS++))
fi

echo -e "${GREEN}[2/4] Construction de l'image Frontend...${NC}"
if ! build_image "frontend" "vocalyx-frontend" "vocalyx-frontend/Containerfile"; then
    ((ERRORS++))
fi

echo -e "${GREEN}[3/4] Construction de l'image Transcription Worker...${NC}"
if ! build_image "transcribe" "vocalyx-transcribe" "vocalyx-transcribe/Containerfile"; then
    ((ERRORS++))
fi

echo -e "${GREEN}[4/4] Construction de l'image Enrichment Worker...${NC}"
if ! build_image "enrichment" "vocalyx-enrichment" "vocalyx-enrichment/Containerfile"; then
    ((ERRORS++))
fi

# Résumé
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    RÉSUMÉ                                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Toutes les images ont été préparées avec succès !${NC}"
    echo ""
    echo -e "${BLUE}Images Vocalyx construites:${NC}"
    podman images | grep "vocalyx-" | grep "$IMAGE_TAG" || echo "  (aucune image trouvée)"
    echo ""
    echo -e "${BLUE}Images officielles téléchargées:${NC}"
    podman images | grep -E "(postgres:15-alpine|redis:7-alpine|haproxy:2.8-alpine|mher/flower:2.0)" || echo "  (aucune image trouvée)"
    echo ""
    echo -e "${GREEN}Durée totale: ${TOTAL_DURATION}s${NC}"
    echo ""
    echo -e "${YELLOW}Prochaines étapes:${NC}"
    echo "  1. Vérifier les images: podman images"
    echo "  2. Déployer avec systemd: ./deploy-podman-systemd.sh"
    echo ""
    exit 0
else
    echo -e "${RED}✗ $ERRORS erreur(s) lors de la construction${NC}"
    echo ""
    echo -e "${YELLOW}Durée totale: ${TOTAL_DURATION}s${NC}"
    echo ""
    echo -e "${YELLOW}Conseils de dépannage:${NC}"
    echo "  - Vérifier les logs d'erreur ci-dessus"
    echo "  - Vérifier que tous les Containerfiles existent"
    echo "  - Vérifier les dépendances dans les Containerfiles"
    echo "  - Essayer avec --no-cache pour forcer une reconstruction complète"
    echo ""
    exit 1
fi

