require 'mkmf'
require "active_support/all"
# require "active_record"
require 'anonymizer'
require 'yaml'
require 'fileutils'
require_relative 'utils'

class Etl
  include Utils

  VALID_APPS = %w[rdv_insertion rdv_solidarites rdv_mairie].freeze

  attr_reader :app, :etl_db_url, :rdv_db_url, :config_url, :config

  def initialize(app:, etl_db_url:, rdv_db_url:, config_url:)
    @app = app
    @etl_db_url = etl_db_url
    @rdv_db_url = rdv_db_url
    @config_url = config_url
    raise "invalid app" if VALID_APPS.exclude?(app)
  end

  def run
    install_dbclient_fetcher
    connect_active_record etl_db_url
    run_command "curl -o config.yml \"#{config_url}\""
    @config = Anonymizer::Config.new(YAML.safe_load(File.read("config.yml")))
    run_command(
      <<~SH.strip_heredoc
        time pg_dump --clean --no-privileges --format tar \
          #{excluded_tables.map { "--exclude-table #{_1}"}.join(" ")} \
          -f #{dump_filename} \
          #{rdv_db_url}
      SH
    ) unless ENV["CACHE_DUMP"] && File.exist?(dump_filename) # for dev purposes
    run_sql_script"clean_public_schema.sql"
    run_command %Q(time pg_restore --clean --if-exists --no-owner --section=pre-data --section=data -d #{etl_db_url} #{dump_filename}) # restore without indexes
    FileUtils.rm(dump_filename) unless ENV["CACHE_DUMP"]
    log_around("Anonymizing database") do
      Anonymizer.anonymize_all_data!(config:)
    end
    run_command %Q(time pg_restore --clean --if-exists --no-owner --section=post-data -d #{etl_db_url} #{dump_filename}) # now restore indexes
    run_sql_command %Q(ALTER TABLE users DROP COLUMN IF EXISTS text_search_terms CASCADE)
    # ERROR:  cannot insert a non-DEFAULT value into column "text_search_terms" (PG::GeneratedAlways)
    # DÉTAIL : Column "text_search_terms" is a generated column.
    run_sql_script"clone_schema.sql"
    run_sql_command %Q(DROP SCHEMA IF EXISTS #{app} CASCADE;)
    run_sql_command %Q(SELECT clone_schema('public', '#{app}', TRUE);)
    run_sql_script"clean_public_schema.sql"
  end

  def dump_filename
    @dump_filename ||= "dump.#{app}.#{Time.now.strftime("%Y-%m-%d")}.pgsql.tar"
  end

  def excluded_tables
    @excluded_tables ||= %w[
      versions
      good_jobs
      good_job_executions
      good_job_settings
      good_job_batches
      good_job_processes
    ].freeze
  end
end
