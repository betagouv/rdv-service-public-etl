# rdv-service-public-etl

ETL de RDV Service Public

```mermaid
sequenceDiagram
    participant ETL as Script ETL
    participant DB_ETL as Metabase Database
    participant DB_RDV as RDV Database
    activate ETL
    GitHub->>ETL: Téléchargement config/anonymizer.yml
    DB_RDV->>ETL: pg_dump
    ETL->>DB_ETL: restore to public schema without indexes
    ETL->>DB_ETL: anonymize
    ETL->>DB_ETL: restore indexes
    ETL->>DB_ETL: move to schema rdv_solidarites, rdv_insertion...
    ETL->>DB_ETL: clean public schema
    deactivate ETL
```

## Usage en local

> [!WARNING]
> Assurez vous de supprimer les fichiers de dumps, les bases de données restaurées, et les mots de passe des users Postgres utilisés en local après vos tests

### Variables d’environnement 

Copiez les variables d’environnement dans un fichier `.env` :

`cp .env.example .env`

### Préparation postgres local

Créer une base de données PostgreSQL et un rôle superuser pour l’ETL.

```sh
createdb rdv-sp-etl
echo "CREATE ROLE rdv_sp_etl_user WITH LOGIN SUPERUSER PASSWORD 'rdv_sp_etl_password'" | psql -d rdv-sp-etl;
```

Mettez à jour dans le `.env` :

`RDV_ETL_DB_URL=postgresql://rdv_sp_etl_user:rdv_sp_etl_password@localhost:5432/rdv-sp-etl`

### Préparation de l’URL de la base de données cible

Dans cet exemple nous configurons pour la base de données de démo de RDV-Solidarités.

En utilisant le CLI scalingo, récupérez le nom de la base de données

```sh
scalingo env-get --app demo-rdv-solidarites --region osc-secnum-fr1  SCALINGO_POSTGRESQL_URL | sed -E 's|.*://.*/([^?]+).*|\1|'
```

Puisque nous allons utiliser le tunnel scalingo, le host et le port de la base de données sont toujours `localhost:10000`

Récupérez les credentials d’un user postgres read-only en vous connectant depuis le dashboard scalingo.

Vous pouvez maintenant renseigner la variable d’environnement dans votre fichier `.env` :

`RDV_SOLIDARITES_DB_URL=postgresql://RO_USER:RO_PASSWORD@localhost:10000/demo_db_name`

### Lancement

Dans un terminal ouvrir un tunnel par exemple vers la db scalingo Postgres de demo-rdv-solidarites avec :

`scalingo db-tunnel --app demo-rdv-solidarites --region osc-secnum-fr1  SCALINGO_POSTGRESQL_URL`

Dans un autre terminal, lancer l’ETL :

`bundle exec ruby main.rb --app rdv_solidarites`

## Usage en production

Pour la DB d’ETL, assurez-vous d’utiliser un rôle superuser PostgreSQL différent du rôle par défaut.
