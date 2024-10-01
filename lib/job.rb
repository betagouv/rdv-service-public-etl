require "sidekiq"

require_relative "etl"
require_relative "utils"
require_relative "apps"

class Job
  include Sidekiq::Job
  include Utils

  def perform(app_name)
    app_config = Apps.get(app_name)

    config_path = if ENV["CONFIG_PATH"] && File.exist?(ENV["CONFIG_PATH"])
                    ENV["CONFIG_PATH"]
                  else
                    run_command "curl -o /tmp/config.yml \"#{app_config.config_url}\""
                    "/tmp/config.yml"
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
  end
end
