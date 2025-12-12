# GitHub Actions pour Vocalyx

Ce répertoire contient les workflows GitHub Actions pour automatiser le CI/CD du projet Vocalyx.

## Workflows disponibles

### 🔨 CI - Build Docker Images (`ci-docker-build.yml`)
Valide que les fichiers Docker Compose et Dockerfiles sont corrects et peuvent être construits.
- Validation de `docker-compose.yml`
- Vérification de l'existence des Dockerfiles
- Test des commandes Makefile

**Déclencheurs :**
- Push sur `main` ou `develop`
- Pull requests vers `main` ou `develop`
- Déclenchement manuel

---

### 🛠️ CI - CLI Validation (`ci-cli-validation.yml`)
Valide le script CLI bash `vocalyx_cli`.
- Vérification de la syntaxe bash
- Analyse avec ShellCheck
- Test des commandes d'aide
- Détection de problèmes courants

**Déclencheurs :**
- Modification de `vocalyx_cli`
- Pull requests modifiant le CLI
- Déclenchement manuel

---

### ✅ CI - YAML Validation (`ci-yaml-validation.yml`)
Valide tous les fichiers YAML du projet.
- Validation de `docker-compose.yml` et `podman-compose.yml`
- Validation des workflows GitHub Actions avec `yamllint`
- Vérification de la syntaxe YAML

**Déclencheurs :**
- Modification de fichiers `.yml` ou `.yaml`
- Modification des workflows GitHub Actions
- Déclenchement manuel

---

### 🔒 CI - Security Scan (`ci-security-scan.yml`)
Effectue des scans de sécurité automatisés.
- **Secret Detection** : Détection de secrets dans le code (Gitleaks)
- **Dependency Scan** : Scan des vulnérabilités des dépendances (Trivy)
- **Dockerfile Scan** : Analyse de sécurité des Dockerfiles (Trivy)

**Déclencheurs :**
- Push sur `main` ou `develop`
- Pull requests vers `main` ou `develop`
- Exécution hebdomadaire (tous les lundis à 2h)
- Déclenchement manuel

---

### 🧪 CI - Integration Tests (`ci-integration-tests.yml`)
Exécute des tests d'intégration avec Docker Compose.
- Démarrage de tous les services
- Vérification de la santé des services (PostgreSQL, Redis, API)
- Tests des endpoints API (`/health`, `/docs`)
- Tests de connexion à la base de données

**Déclencheurs :**
- Push sur `main` ou `develop`
- Pull requests vers `main` ou `develop`
- Déclenchement manuel

**Note :** Ce workflow peut prendre plusieurs minutes en raison du démarrage des services Docker.

---

### 📋 CI - Code Quality (`ci-code-quality.yml`)
Vérifie la qualité du code et de la documentation.
- Vérification de l'existence des fichiers de documentation
- Validation des fichiers de configuration (`.env.example`, `.gitignore`)
- Détection de secrets potentiels dans le code
- Validation du Makefile

**Déclencheurs :**
- Push sur `main` ou `develop`
- Pull requests vers `main` ou `develop`
- Déclenchement manuel

---

### 🚀 Release (`release.yml`)
Crée une release GitHub lors de la création d'un tag de version.
- Génération automatique des notes de release
- Création du tag GitHub
- Possibilité de build et push des images Docker (optionnel)

**Déclencheurs :**
- Push d'un tag `v*.*.*` (ex: `v1.0.0`)
- Déclenchement manuel avec saisie de la version

**Utilisation :**
```bash
# Créer un tag et pousser
git tag v1.0.0
git push origin v1.0.0
```

---

## Configuration requise

### Secrets GitHub

Pour utiliser certaines fonctionnalités avancées, vous devrez configurer les secrets suivants dans les paramètres GitHub du dépôt :

- `GITHUB_TOKEN` : Automatiquement fourni par GitHub Actions
- (Optionnel) Secrets pour Docker Registry si vous publiez des images

### Variables d'environnement

Les workflows utilisent des variables d'environnement par défaut. Pour les modifier, allez dans :
`Settings > Secrets and variables > Actions > Variables`

---

## Personnalisation

### Modifier les déclencheurs

Modifiez la section `on:` de chaque workflow pour changer quand ils s'exécutent.

### Ajouter de nouveaux checks

Pour ajouter de nouveaux checks de qualité, modifiez le workflow `ci-code-quality.yml` ou créez un nouveau workflow.

### Désactiver un workflow

Pour désactiver temporairement un workflow, ajoutez cette condition au job :
```yaml
if: false
```

---

## Statut des workflows

Vous pouvez voir le statut des workflows dans l'onglet "Actions" de votre dépôt GitHub.

---

## Support

Pour toute question ou problème avec les workflows, consultez :
- La [documentation GitHub Actions](https://docs.github.com/en/actions)
- Les logs d'exécution dans l'onglet "Actions"
- Les issues du projet
