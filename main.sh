#!/usr/bin/env bash
set -e
# Inspiré par https://doc.scalingo.com/platform/databases/duplicate

if [ "$#" -lt 2 ]; then
    echo "Usage ./main.sh <app> <env> <schema optionnel>"
    echo "<app> choisir parmis: rdvi, rdvsp"
    echo "<env> choisir parmis: demo, prod"
    echo "<schema> sera par défaut le nom de l'app, mais peut être surchargé ici"
    exit 1
fi

declare -A available_apps

available_apps["rdvi_demo"]="rdv-insertion-demo"
available_apps["rdvi_prod"]="rdv-insertion-prod"
available_apps["rdvsp_demo"]="demo-rdv-solidarites"
available_apps["rdvsp_prod"]="production-rdv-solidarites"

app=$1
env=$2
schema_name="${3:-$app}"
database=${available_apps["${app}_${env}"]}

archive_name="backup.tar.gz"

if ! command -v scalingo &> /dev/null; then
  echo ""
  echo "Install the Scalingo CLI tool in the container:"
  echo "install-scalingo-cli"
  echo ""
  install-scalingo-cli
fi

if command -v dbclient-fetcher &> /dev/null; then
  echo ""
  echo "Install additional tools to interact with the database:"
  echo "dbclient-fetcher pgsql"
  echo ""
  dbclient-fetcher pgsql
fi

if [[ "$(scalingo whoami)" == *"user unauthenticated"* ]]; then
  echo ""
  echo "Login to Scalingo:"
  echo "Cette commande nécessite un login par un membre de l'équipe"
  echo "On préfère faire un login à chaque rafraichissement des données plutôt que de laisser un token scalingo en variable d'env"
  echo ""
  scalingo login --password-only
fi

echo ""
echo "Retrieve the ETL Scalingo app's PostgreSQL addon id..."
echo ""
etl_addon_id="$( scalingo --region osc-secnum-fr1 --app rdv-service-public-etl addons \
  | grep "PostgreSQL" \
  | cut -d "|" -f 3 \
  | tr -d " " )"

echo ""
echo "Retrieve the RDV Scalingo app's PostgreSQL addon id..."
echo ""
rdv_addon_id="$( scalingo --region osc-secnum-fr1 --app "${database}" addons \
                 | grep "PostgreSQL" \
                 | cut -d "|" -f 3 \
                 | tr -d " " )"

if [ ! -f "${archive_name}" ]; then
  echo ""
  echo "Downloading the latest backup available for the RDV db..."
  echo "scalingo  --region osc-secnum-fr1 --app "${database}" --addon "${rdv_addon_id}" backups-download --output "${archive_name}""
  echo ""
  scalingo  --region osc-secnum-fr1 --app "${database}" --addon "${rdv_addon_id}" backups-download --output "${archive_name}"
fi

apppath=$(if [[ -d "/app/" ]]; then echo "/app/"; else echo "."; fi)

echo ""
echo "Extract the archive containing the downloaded backup..."
echo "tar --extract --verbose --file="${archive_name}" --directory="${apppath}/" 2>/dev/null"
echo ""
tar --extract --verbose --file="${archive_name}" --directory="${apppath}/" 2>/dev/null

echo ""
echo "Suppression du role postgres utilisé par metabase"
echo ""
scalingo database-delete-user --region osc-secnum-fr1 --app rdv-service-public-etl --addon "${etl_addon_id}" rdv_service_public_metabase
echo "La base de données n'est plus accessible par metabase"

echo ""
echo "Chargement du dump..."
echo "pg_restore -O -x -f raw.sql *.pgsql"
echo ""
pg_restore -O -x -f raw.sql *.pgsql

echo ""
echo "Rename schema..."
echo "sed -i "s/public/${schema_name}/g" raw.sql"
echo ""
/opt/homebrew/Cellar/gnu-sed/4.9/bin/gsed -i "s/public/${schema_name}/g" raw.sql

if [[ "$schema_name" != "public" ]]; then
  echo ""
  echo "(re)-création du schéma ${schema_name}"
  echo "psql \"${DATABASE_URL}\" -c \"DROP SCHEMA IF EXISTS \"${schema_name}\" CASCADE;\""
  echo "psql \"${DATABASE_URL}\" -c \"CREATE SCHEMA \"${schema_name}\";\""
  echo ""
  psql "${DATABASE_URL}" -c "DROP SCHEMA IF EXISTS \"${schema_name}\" CASCADE;"
  psql "${DATABASE_URL}" -c "CREATE SCHEMA \"${schema_name}\";"
else
  echo ""
  echo "Nettoyage du schéma public"
  echo "psql  -v ON_ERROR_STOP=0 "${DATABASE_URL}" < ${apppath}/clean_public_schema.sql"
  echo ""
  psql  -v ON_ERROR_STOP=0 "${DATABASE_URL}" < ${apppath}/clean_public_schema.sql
fi

echo ""
echo "Chargement du dump dans la base"
echo "psql  -v ON_ERROR_STOP=0 "${DATABASE_URL}" < ${apppath}/raw.sql"
echo ""
psql  -v ON_ERROR_STOP=0 "${DATABASE_URL}" < ${apppath}/raw.sql

echo ""
echo "Anonymisation de la base"
echo "time bundle exec ./anonymize_database.rb "${app}" "${schema_name}""
echo ""
time bundle exec ruby anonymize_database.rb "${app}" "${schema_name}"

echo ""
echo "Re-création du role Postgres rdv_service_public_metabase"
echo "Merci de copier/coller le mot de passe stocké dans METABASE_DB_ROLE_PASSWORD: ${METABASE_DB_ROLE_PASSWORD}"
echo "scalingo database-create-user --region osc-secnum-fr1 --app rdv-service-public-etl --addon "${etl_addon_id}" --read-only rdv_service_public_metabase"
echo ""
scalingo database-create-user --region osc-secnum-fr1 --app rdv-service-public-etl --addon "${etl_addon_id}" --read-only rdv_service_public_metabase

echo ""
echo "Grant usage on schema ${schema_name} to rdv_service_public_metabase"
echo "psql "${DATABASE_URL}" -c "GRANT USAGE ON SCHEMA ${schema_name} TO rdv_service_public_metabase;""
echo "psql "${DATABASE_URL}" -c "GRANT SELECT ON ALL TABLES IN SCHEMA ${schema_name} TO rdv_service_public_metabase;""
echo ""
psql "${DATABASE_URL}" -c "GRANT USAGE ON SCHEMA ${schema_name} TO rdv_service_public_metabase;"
psql "${DATABASE_URL}" -c "GRANT SELECT ON ALL TABLES IN SCHEMA ${schema_name} TO rdv_service_public_metabase;"
