require "active_support/all"
require 'optparse'
require 'dotenv'

require_relative "lib/etl"

Dotenv.load

app = nil
OptionParser.new do |opts|
  opts.on('-a', '--app APP', Etl::VALID_APPS) { app = _1 }
end.parse!

config_url, rdv_db_url = {
  "rdv_insertion" => [
    ENV["ANONYMIZER_CONFIG_RDV_INSERTION_URL"],
    ENV["RDV_INSERTION_DB_URL"]
  ],
  "rdv_solidarites" => [
    ENV["ANONYMIZER_CONFIG_RDV_SERVICE_PUBLIC_URL"],
    ENV["RDV_SOLIDARITES_DB_URL"]
  ],
  "rdv_service_public" => [
    ENV["ANONYMIZER_CONFIG_RDV_SERVICE_PUBLIC_URL"],
    ENV["RDV_SERVICE_PUBLIC_DB_URL"]
  ]
}[app]

etl_db_url = ENV["ETL_DB_URL"]

Etl.new(app:, etl_db_url:, rdv_db_url:, config_url:).run
