require "active_support/all"
require 'optparse'
require 'dotenv'

require_relative "lib/etl"

Dotenv.load

app, use_cache, skip_restore = nil, false, false

OptionParser.new do |opts|
  opts.on('-a', '--app APP', Etl::VALID_APPS) { app = _1 }
  opts.on('--use-cache') { use_cache = true }
  opts.on('--skip-restore') { skip_restore = true }
end.parse!

config_url = {
  "rdv_insertion" => ENV["ANONYMIZER_CONFIG_RDV_INSERTION_URL"],
  "rdv_solidarites" => ENV["ANONYMIZER_CONFIG_RDV_SERVICE_PUBLIC_URL"],
  "rdv_service_public" => ENV["ANONYMIZER_CONFIG_RDV_SERVICE_PUBLIC_URL"],
}[app]

etl_db_url = ENV["ETL_DB_URL"]
rdv_db_url = ENV["#{app.upcase}_DB_URL"]

Etl.new(app:, etl_db_url:, rdv_db_url:, config_url:, use_cache:, skip_restore:).run
