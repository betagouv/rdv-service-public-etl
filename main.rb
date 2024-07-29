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

# to avoid logging sensitive passwords, we extract them from env vars into a .pgpass file
etl_db_url, rdv_db_url = [ENV["ETL_DB_URL"], ENV["#{app.upcase}_DB_URL"]]
pgpass_path = File.expand_path(".pgpass", File.dirname(__FILE__))
begin
  etl_db_url, rdv_db_url = Utils.extract_passwords_to_pgpass(pgpass_path, [etl_db_url, rdv_db_url])
  Etl.new(app:, etl_db_url:, rdv_db_url:, config_url:, pgpass_path:, use_cache:, skip_restore:).run
ensure
  FileUtils.rm_f pgpass_path
end
