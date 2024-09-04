require "active_support/all"
require 'optparse'
require 'dotenv'

require_relative "lib/etl"

Dotenv.load

app = nil
OptionParser.new do |opts|
  opts.on('-a', '--app APP', Etl::VALID_APPS) { app = _1 }
end.parse!

config_url_env_var, rdv_db_url_env_var = {
  "rdv_insertion" => [
    "ANONYMIZER_CONFIG_RDV_INSERTION_URL",
    "RDV_INSERTION_DB_URL"
  ],
  "rdv_solidarites" => [
    "ANONYMIZER_CONFIG_RDV_SERVICE_PUBLIC_URL",
    "RDV_SOLIDARITES_DB_URL"
  ],
  "rdv_service_public" => [
    "ANONYMIZER_CONFIG_RDV_SERVICE_PUBLIC_URL",
    "RDV_SERVICE_PUBLIC_DB_URL"
  ]
}[app]

etl_db_url_env_var = "ETL_DB_URL"
metabase_username_env_var = "METABASE_USERNAME"

[
  config_url_env_var,
  rdv_db_url_env_var,
  etl_db_url_env_var,
  metabase_username_env_var
].each do |env_var|
  raise "Missing environment variable #{env_var}" if ENV[env_var].blank?
end

config_url = ENV[config_url_env_var]
rdv_db_url = ENV[rdv_db_url_env_var]
etl_db_url = ENV[etl_db_url_env_var]
metabase_username = ENV[metabase_username_env_var]

Etl.new(app:, etl_db_url:, rdv_db_url:, config_url:, metabase_username:).run
