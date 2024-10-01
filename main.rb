require 'optparse'
require 'dotenv'

require_relative "lib/etl"
require_relative "lib/utils"
require_relative "lib/apps"

Dotenv.load

include Utils

app = nil
OptionParser.new do |opts|
  opts.on('-a', '--app APP', Apps.valid_names) { app = _1 }
end.parse!

app_config = Apps.get(app)

config_path = if ENV["CONFIG_PATH"] && File.exist?(ENV["CONFIG_PATH"])
  ENV["CONFIG_PATH"]
else
  run_command "curl -o config.yml \"#{app_config.config_url}\""
  "config.yml"
end

rdv_db_url_env_var = app_config.source_url_env_var

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
