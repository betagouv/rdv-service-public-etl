# rdv-service-public-etl

ETL de RDV Service Public

## Usage

`bundle exec ruby main.rb --app rdv_solidarites`

## Développement

Créer la db Postgres rdv-sp-etl :

```sh
createdb rdv-sp-etl
psql -d rdv-sp-etl -c "CREATE EXTENSION unaccent;"
```

Dans un terminal ouvrir un tunnel par exemple vers la db scalingo Postgres de demo-rdv-solidarites avec :

`scalingo db-tunnel --app demo-rdv-solidarites --region osc-secnum-fr1  SCALINGO_POSTGRESQL_URL`

Puis copier les variables d’environnement dans un fichier `.env` :

`cp .env.sample .env`

et modifier ETL_DATABASE_URL et RDV_DATABASE_URL pour les adapter à votre environnement.
Avec le tunnel scalingo, récupérer les credentials d’un user R-O et les mettre dans l’URL mais l’host reste localhost et le port est celui donné par la commande de tunnel.
