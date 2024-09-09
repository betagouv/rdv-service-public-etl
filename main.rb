require "active_support/all"
require 'optparse'
require 'dotenv'

require_relative "lib/etl"

Dotenv.load



app = nil
OptionParser.new do |opts|
  opts.on('-a', '--app APP', Etl::VALID_APPS) { app = _1 }
end.parse!

config_url = {
  "rdv_insertion" => "https://raw.githubusercontent.com/adipasquale/rdv-insertion/feature/anonymizer-config/config/anonymizer.yml",
  "rdv_solidarites" => "https://raw.githubusercontent.com/betagouv/rdv-service-public/refactor/anonymizer-gem/config/anonymizer.yml",
  "rdv_service_public" => "https://raw.githubusercontent.com/betagouv/rdv-service-public/refactor/anonymizer-gem/config/anonymizer.yml"
}[app]

rdv_db_url_env_var = {
  "rdv_insertion" => "RDV_INSERTION_DB_URL",
  "rdv_solidarites" => "RDV_SOLIDARITES_DB_URL",
  "rdv_service_public" => "RDV_SERVICE_PUBLIC_DB_URL"
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

Etl.new(app:, etl_db_url:, rdv_db_url:, config_url:, metabase_username:).run
