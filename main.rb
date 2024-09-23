require "active_support/all"
require 'optparse'
require 'dotenv'

require_relative "lib/etl"
require_relative "lib/utils"

Dotenv.load

include Utils

app = nil
OptionParser.new do |opts|
  opts.on('-a', '--app APP', Etl::VALID_APPS) { app = _1 }
end.parse!

config_path = if ENV["CONFIG_PATH"] && File.exist?(ENV["CONFIG_PATH"])
  ENV["CONFIG_PATH"]
else
  config_url = {
    "rdvi" => "https://raw.githubusercontent.com/betagouv/rdv-insertion/staging/config/anonymizer.yml",
    "rdvs" => "https://raw.githubusercontent.com/betagouv/rdv-service-public/production/config/anonymizer.yml",
    "rdvsp" => "https://raw.githubusercontent.com/betagouv/rdv-service-public/production/config/anonymizer.yml"
  }[app]
  run_command "curl -o config.yml \"#{config_url}\""
  "config.yml"
end

rdv_db_url_env_var = {
  "rdvi" => "RDV_INSERTION_DB_URL",
  "rdvs" => "RDV_SOLIDARITES_DB_URL",
  "rdvsp" => "RDV_SERVICE_PUBLIC_DB_URL"
}[app]

etl_db_url_env_var = "ETL_DB_URL"
metabase_username_env_var = "METABASE_USERNAME"

[
  rdv_db_url_env_var,
  etl_db_url_env_var,
  metabase_username_env_var
].each do |env_var|
  raise "Missing environment variable #{env_var}" if ENV[env_var].blank?
end

rdv_db_url = ENV[rdv_db_url_env_var]
etl_db_url = ENV[etl_db_url_env_var]
metabase_username = ENV[metabase_username_env_var]

Etl.new(app:, etl_db_url:, rdv_db_url:, config_path:, metabase_username:).run
