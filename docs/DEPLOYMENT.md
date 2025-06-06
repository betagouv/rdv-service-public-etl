# Déploiement de RDV Service Public ETL

Ce document décrit le processus de déploiement de l'application RDV Service Public ETL via une image Docker publiée dans GitHub Container Registry (GHCR).

L'exemple pris pour cette documentation est un déploiement avec Terraform sur Scaleway

## Architecture de déploiement

L'architecture de déploiement est composée de deux projets distincts :

1. **Projet d'application ETL** (ce projet)
    - Contient le code Ruby de l'ETL
    - Inclut le Dockerfile pour la construction de l'image
    - Configure le pipeline CI/CD pour construire et publier l'image Docker dans GHCR

2. **Projet de déploiement** (dépôt séparé)
    - Contient la configuration de déploiement, par exemple Terraform
    - Référence l'image Docker publiée dans GHCR
    - Gère le déploiement sur l'hébergeur de votre choix

## Configuration CI/CD pour la publication de l'image

Ce projet inclut un workflow GitHub Actions (`.github/workflows/build-and-push.yml`) qui construit et publie automatiquement l'image Docker dans GitHub Container Registry à chaque push sur la branche principale ou à chaque tag.

### Avantages de GitHub Container Registry

- Intégration native avec GitHub
- Authentification simplifiée avec les jetons GitHub
- Bande passante et stockage inclus avec votre compte GitHub
- Gestion des permissions basée sur les rôles GitHub

### Secrets nécessaires

Aucun secret supplémentaire n'est nécessaire pour GHCR, car le workflow utilise déjà `GITHUB_TOKEN` qui est automatiquement fourni par GitHub Actions.

### Tags des images

Les images sont taguées automatiquement selon ces règles :
- Pour chaque branche : `{nom-de-branche}`
- Pour chaque tag : `{tag}`
- Pour chaque commit : `{sha-court}`
- Pour la branche par défaut : `latest`

## Publication manuelle de l'image

Si vous souhaitez publier manuellement l'image, vous pouvez utiliser les commandes suivantes :

```bash
# Authentification à GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Construction de l'image
docker build -t ghcr.io/betagouv/multi-schema-postgres-etl:latest .

# Publication de l'image
docker push ghcr.io/betagouv/multi-schema-postgres-etl:latest
```

## Utilisation dans le projet de déploiement

Pour utiliser cette image dans votre projet de déploiement, référencez-la dans votre configuration Terraform :

```hcl
resource "scaleway_job_definition" "etl_job" {
   name      = "${local.rdv_etl_name}-job"
   region    = local.region
   memory_limit = 512  # 512 Mo
   cpu_limit = 140  # 140 mCPU (0.14 vCPU)
   timeout = "15m"  # 1 heure de timeout max
   image_uri = "ghcr.io/betagouv/multi-schema-postgres-etl:latest"

   cron {
      schedule = local.rdv_etl_cron_schedule # cron at 04:05 on day-of-month 1
      timezone = "Europe/Paris"
   }

   # Variables d'environnement nécessaires au fonctionnement
   env = {
      APP           = "aei"
      CONFIG_PATH   = "https://gitlab.com/incubateur-territoires/startups/agents-intervention/agents-en-intervention/-/raw/main/config.etl.yml"
      METABASE_USERNAME = "metabase" # database metabase user
      RUBY_ENV = "production"
      # ETL_DB_URL pour la base de données cible
      ETL_DB_URL = "postgresql://${urlencode(scaleway_rdb_user.etl.name)}:${urlencode(random_password.etl_db_password.result)}@${scaleway_rdb_instance.metabase.load_balancer[0].ip}:${scaleway_rdb_instance.metabase.load_balancer[0].port}/${scaleway_rdb_database.etl.name}"
      # ORIGIN_DB_URL pour la base de données source (production)
      ORIGIN_DB_URL = module.prod.database_url
   }
}
```

Vous pouvez également paramétrer le tag de l'image via une variable Terraform :

```hcl
variable "image_tag" {
  type    = string
  default = "latest"
}

resource "scaleway_job_definition" "etl_job" {
  image_uri = "ghcr.io/betagouv/multi-schema-postgres-etl:${var.image_tag}"
  # Autres configurations...
}
```
