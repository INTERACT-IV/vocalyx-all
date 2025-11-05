#!/usr/bin/env python3
"""
Script d'initialisation de la base de données Vocalyx
Peut être exécuté indépendamment pour éviter les problèmes OOM
"""

import sys
import os
import time
import logging

# Ajouter le chemin du module
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

def wait_for_postgres(max_retries=30, delay=2):
    """Attend que PostgreSQL soit prêt"""
    from sqlalchemy import create_engine
    from config import Config
    
    config = Config()
    logger.info("⏳ Waiting for PostgreSQL to be ready...")
    
    for i in range(max_retries):
        try:
            engine = create_engine(config.database_url)
            connection = engine.connect()
            connection.close()
            logger.info("✅ PostgreSQL is ready!")
            return True
        except Exception as e:
            if i < max_retries - 1:
                logger.info(f"PostgreSQL not ready yet (attempt {i+1}/{max_retries})...")
                time.sleep(delay)
            else:
                logger.error(f"❌ Failed to connect to PostgreSQL: {e}")
                return False
    
    return False

def init_database():
    """Initialise la base de données"""
    try:
        from database import Base, engine, get_or_create_project, SessionLocal
        from config import Config
        
        config = Config()
        
        logger.info("🗄️  Creating database tables...")
        Base.metadata.create_all(bind=engine)
        logger.info("✅ Tables created successfully")
        
        # Créer le projet admin
        logger.info(f"👤 Creating admin project: {config.admin_project_name}")
        db = SessionLocal()
        try:
            admin_project = get_or_create_project(db, config.admin_project_name)
            logger.info(f"✅ Admin project ready: {admin_project.name}")
            logger.info(f"🔑 Admin API Key: {admin_project.api_key}")
        finally:
            db.close()
        
        logger.info("🎉 Database initialization complete!")
        return True
        
    except Exception as e:
        logger.error(f"❌ Database initialization failed: {e}", exc_info=True)
        return False

def main():
    """Point d'entrée principal"""
    logger.info("🚀 Starting Vocalyx database initialization...")
    
    # Attendre que PostgreSQL soit prêt
    if not wait_for_postgres():
        logger.error("❌ Could not connect to PostgreSQL")
        sys.exit(1)
    
    # Initialiser la base de données
    if not init_database():
        logger.error("❌ Database initialization failed")
        sys.exit(1)
    
    logger.info("✅ All done!")
    sys.exit(0)

if __name__ == "__main__":
    main()