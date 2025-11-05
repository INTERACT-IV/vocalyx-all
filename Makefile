# ============================================================================
# Vocalyx - Makefile
# ============================================================================
# Commandes utiles pour gérer l'infrastructure Docker
# ============================================================================

.PHONY: help build up down restart logs clean init-db ps scale health

# Couleurs pour l'affichage
BLUE=\033[0;34m
GREEN=\033[0;32m
RED=\033[0;31m
NC=\033[0m # No Color

help: ## Afficher l'aide
	@echo "$(BLUE)Vocalyx - Commandes Disponibles$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

# ==========================================================================
# CONSTRUCTION ET DÉMARRAGE
# ==========================================================================

build: ## Construire toutes les images Docker
	@echo "$(BLUE)Building Docker images...$(NC)"
	docker-compose build --no-cache

up: ## Démarrer tous les services
	@echo "$(BLUE)Starting all services...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo ""
	@echo "  Frontend:  http://localhost:8080"
	@echo "  API:       http://localhost:8000"
	@echo "  API Docs:  http://localhost:8000/docs"
	@echo "  Flower:    http://localhost:5555"
	@echo ""

down: ## Arrêter tous les services
	@echo "$(BLUE)Stopping all services...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: down up ## Redémarrer tous les services

# ==========================================================================
# LOGS
# ==========================================================================

logs: ## Afficher les logs de tous les services
	docker-compose logs -f

logs-api: ## Logs de vocalyx-api
	docker-compose logs -f vocalyx-api

logs-frontend: ## Logs de vocalyx-frontend
	docker-compose logs -f vocalyx-frontend

logs-worker-01: ## Logs du worker 01
	docker-compose logs -f vocalyx-transcribe-01

logs-worker-02: ## Logs du worker 02
	docker-compose logs -f vocalyx-transcribe-02

logs-postgres: ## Logs de PostgreSQL
	docker-compose logs -f postgres

logs-redis: ## Logs de Redis
	docker-compose logs -f redis

logs-flower: ## Logs de Flower
	docker-compose logs -f flower

# ==========================================================================
# STATUT ET MONITORING
# ==========================================================================

ps: ## Lister les conteneurs en cours d'exécution
	@docker-compose ps

health: ## Vérifier la santé des services
	@echo "$(BLUE)Checking services health...$(NC)"
	@echo ""
	@echo "API:"
	@curl -s http://localhost:8000/health | jq '.' || echo "$(RED)✗ API not responding$(NC)"
	@echo ""
	@echo "Frontend:"
	@curl -s http://localhost:8080/health | jq '.' || echo "$(RED)✗ Frontend not responding$(NC)"
	@echo ""

stats: ## Statistiques des conteneurs
	docker stats --no-stream

# ==========================================================================
# BASE DE DONNÉES
# ==========================================================================

init-db: ## Initialiser la base de données
	@echo "$(BLUE)Initializing database...$(NC)"
	docker-compose exec vocalyx-api python -c "from database import init_db; init_db()"
	@echo "$(GREEN)✓ Database initialized$(NC)"

db-shell: ## Ouvrir un shell PostgreSQL
	docker-compose exec postgres psql -U vocalyx -d vocalyx_db

db-backup: ## Sauvegarder la base de données
	@echo "$(BLUE)Creating database backup...$(NC)"
	mkdir -p backups
	docker-compose exec -T postgres pg_dump -U vocalyx vocalyx_db > backups/vocalyx_backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)✓ Backup created in backups/$(NC)"

db-restore: ## Restaurer la base de données (usage: make db-restore FILE=backup.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Usage: make db-restore FILE=path/to/backup.sql$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring database from $(FILE)...$(NC)"
	docker-compose exec -T postgres psql -U vocalyx -d vocalyx_db < $(FILE)
	@echo "$(GREEN)✓ Database restored$(NC)"

# ==========================================================================
# CELERY & WORKERS
# ==========================================================================

scale-workers: ## Scaler les workers (usage: make scale-workers N=3)
	@if [ -z "$(N)" ]; then \
		echo "$(RED)Usage: make scale-workers N=3$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Scaling workers to $(N)...$(NC)"
	docker-compose up -d --scale vocalyx-transcribe-01=$(N)
	@echo "$(GREEN)✓ Workers scaled to $(N)$(NC)"

celery-status: ## Statut des workers Celery
	docker-compose exec vocalyx-transcribe-01 celery -A worker.celery_app inspect active

celery-stats: ## Statistiques des workers Celery
	docker-compose exec vocalyx-transcribe-01 celery -A worker.celery_app inspect stats

celery-purge: ## Purger toutes les tâches en attente (⚠️ DANGER)
	@echo "$(RED)⚠️  This will delete all pending tasks!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose exec vocalyx-transcribe-01 celery -A worker.celery_app purge -f; \
		echo "$(GREEN)✓ Tasks purged$(NC)"; \
	fi

# ==========================================================================
# NETTOYAGE
# ==========================================================================

clean: ## Arrêter et supprimer les conteneurs (préserve les volumes)
	@echo "$(BLUE)Cleaning containers...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ Containers removed$(NC)"

clean-all: ## Arrêter et tout supprimer (conteneurs + volumes)
	@echo "$(RED)⚠️  This will delete all data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "$(GREEN)✓ Everything removed$(NC)"; \
	fi

clean-uploads: ## Nettoyer les fichiers uploadés
	@echo "$(BLUE)Cleaning uploads...$(NC)"
	rm -rf shared_uploads/*
	@echo "$(GREEN)✓ Uploads cleaned$(NC)"

clean-logs: ## Nettoyer les logs
	@echo "$(BLUE)Cleaning logs...$(NC)"
	rm -rf shared_logs/*
	@echo "$(GREEN)✓ Logs cleaned$(NC)"

prune: ## Nettoyer les images et volumes inutilisés
	@echo "$(BLUE)Pruning Docker system...$(NC)"
	docker system prune -f
	docker volume prune -f
	@echo "$(GREEN)✓ System pruned$(NC)"

# ==========================================================================
# DÉVELOPPEMENT
# ==========================================================================

shell-api: ## Shell dans le conteneur API
	docker-compose exec vocalyx-api /bin/bash

shell-frontend: ## Shell dans le conteneur Frontend
	docker-compose exec vocalyx-frontend /bin/bash

shell-worker: ## Shell dans le conteneur Worker 01
	docker-compose exec vocalyx-transcribe-01 /bin/bash

dev: ## Mode développement (avec rebuild)
	docker-compose up --build

prod: build up ## Mode production (build + up)

# ==========================================================================
# TESTS
# ==========================================================================

test-api: ## Tester l'API
	@echo "$(BLUE)Testing API...$(NC)"
	curl -X GET http://localhost:8000/health | jq '.'
	curl -X GET http://localhost:8000/docs

test-upload: ## Tester un upload (nécessite un fichier test.wav)
	@if [ ! -f test.wav ]; then \
		echo "$(RED)File test.wav not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Testing upload...$(NC)"
	curl -X POST http://localhost:8000/api/transcriptions \
		-H "X-API-Key: YOUR_PROJECT_KEY" \
		-F "file=@test.wav" \
		-F "project_name=ISICOMTECH" \
		-F "use_vad=true" | jq '.'

# ==========================================================================
# INSTALLATION
# ==========================================================================

install: ## Installation complète (1ère fois)
	@echo "$(BLUE)Installing Vocalyx...$(NC)"
	@echo ""
	@echo "1. Copying .env file..."
	@if [ ! -f .env ]; then cp .env.example .env; echo "$(GREEN)✓ .env created$(NC)"; else echo "$(GREEN)✓ .env already exists$(NC)"; fi
	@echo ""
	@echo "2. Creating directories..."
	@mkdir -p shared_uploads shared_logs whisper_models backups
	@echo "$(GREEN)✓ Directories created$(NC)"
	@echo ""
	@echo "3. Building images..."
	@$(MAKE) build
	@echo ""
	@echo "4. Starting services..."
	@$(MAKE) up
	@echo ""
	@echo "5. Waiting for services to be ready..."
	@sleep 10
	@echo ""
	@echo "6. Initializing database..."
	@$(MAKE) init-db
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)✓ Installation complete!$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@echo "Access the application:"
	@echo "  Frontend:  http://localhost:8080"
	@echo "  API:       http://localhost:8000"
	@echo "  API Docs:  http://localhost:8000/docs"
	@echo "  Flower:    http://localhost:5555"
	@echo ""
	@echo "⚠️  Don't forget to edit .env and change the secret keys!"
	@echo ""

update: ## Mettre à jour (pull + rebuild)
	@echo "$(BLUE)Updating Vocalyx...$(NC)"
	git pull
	$(MAKE) down
	$(MAKE) build
	$(MAKE) up
	@echo "$(GREEN)✓ Update complete$(NC)"