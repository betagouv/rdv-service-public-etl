require "active_support/all"
require 'optparse'
require 'dotenv'

require_relative "lib/etl"
require_relative "lib/utils"

Dotenv.load

include Utils

app = ENV["APP"]
OptionParser.new do |opts|
  opts.on('-a', '--app APP', Etl::VALID_APPS) { app = _1 }
end.parse!

if app.nil?
  raise "Définissez une variable d'environnement APP ou passez un argument --app"
end



config_url = {
    "rdvi" => "https://raw.githubusercontent.com/betagouv/rdv-insertion/main/config/anonymizer.yml",
    "rdvs" => "https://raw.githubusercontent.com/betagouv/rdv-service-public/production/config/anonymizer.yml",
    "rdvsp" => "https://raw.githubusercontent.com/betagouv/rdv-service-public/production/config/anonymizer.yml"
}

rdv_db_url_list = {
  "rdvi" => "RDV_INSERTION_DB_URL",
  "rdvs" => "RDV_SOLIDARITES_DB_URL",
  "rdvsp" => "RDV_SERVICE_PUBLIC_DB_URL"
}

if config_url.key?(app)
    config_path = config_url[app]
    origin_db_url_env_var = rdv_db_url_list[app]
else
    unless ENV["CONFIG_PATH"]
      raise "La variable d'environnement CONFIG_PATH n'est pas définie"
    end


    config_path = ENV["CONFIG_PATH"]

    # Si le nom du fichier commence par https://, alors il s'agit d'une URL
    if config_path.starts_with?("https://")
      # Télécharger le fichier
        run_command "curl -o config.yml \"#{config_path}\""
        config_path = "config.yml"
    end

    unless File.exist?(config_path)
      raise "La variable d'environnement CONFIG_PATH pointe vers un fichier inexistant"
    end

    origin_db_url_env_var = "ORIGIN_DB_URL"
end

etl_db_url_env_var = "ETL_DB_URL"
metabase_username_env_var = "METABASE_USERNAME"

[
  origin_db_url_env_var,
  etl_db_url_env_var,
  metabase_username_env_var
].each do |env_var|
  raise "Missing environment variable #{env_var}" if ENV[env_var].blank?
end

origin_db_url = ENV[origin_db_url_env_var]
etl_db_url = ENV[etl_db_url_env_var]
metabase_username = ENV[metabase_username_env_var]

Etl.new(app:, etl_db_url:, origin_db_url:, config_path:, metabase_username:).run
