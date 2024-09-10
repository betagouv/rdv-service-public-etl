require 'anonymizer'
require 'yaml'
require "fileutils"

require_relative 'utils'

class Etl
  include Utils

  VALID_APPS = %w[rdv_insertion rdv_solidarites rdv_service_public].freeze

  attr_reader :app, :etl_db_url, :rdv_db_url, :config_url, :metabase_username

  def initialize(app:, etl_db_url:, rdv_db_url:, config_url:, metabase_username:)
    @app = app
    raise 'invalid app' if VALID_APPS.exclude?(app)

    @etl_db_url = etl_db_url
    @rdv_db_url = rdv_db_url
    @config_url = config_url
    @metabase_username = metabase_username
  end

  def run
    if !find_executable("pg_dump") && find_executable('dbclient-fetcher')
      system "dbclient-fetcher pgsql 15" # only useful on Scalingo apps
    end

    # STEP : download and load anonymizer config
    if ENV["CONFIG_PATH"] && File.exist?(ENV["CONFIG_PATH"])
      config_path = ENV["CONFIG_PATH"]
    else
      run_command "curl -o config.yml \"#{config_url}\""
      config_path = "config.yml"
    end
    @config = Anonymizer::Config.new(YAML.safe_load(File.read(config_path)))

    # make sure RDV db connection works
    log_around "connect to RDV database #{rdv_db_url}" do
      ActiveRecord::Base.establish_connection rdv_db_url
      ActiveRecord::Base.connection # triggers connection
    end

    log_around "validate config exhaustivity" do
      Anonymizer.validate_exhaustivity!(config: @config)
    end

    ActiveRecord::Base.connection_handler.clear_all_connections!

    # make sure ETL db connection works to avoid useless dumps
    log_around "connect to ETL database #{etl_db_url}" do
      ActiveRecord::Base.establish_connection etl_db_url
      ActiveRecord::Base.connection # triggers connection
    end

    # STEP : dump from distant RDVSP or RDVI database
    unless ENV['CACHE_DUMP'] && File.exist?(dump_filename)
      run_command(
        <<~SH.strip_heredoc
          time pg_dump --clean --no-privileges --format tar \
            #{@config.truncated_table_names.map { "--exclude-table #{_1}" }.join(' ')} \
            -f #{dump_filename} \
            #{rdv_db_url}
        SH
      )
    end

    # STEP : restore dump to ETL database, without indexes, in public schema
    # cf https://www.postgresql.org/docs/current/app-pgrestore.html
    # The data section contains actual table data as well as large-object definitions.
    # Post-data items consist of definitions of indexes, triggers, rules and constraints other than validated check constraints.
    # Pre-data items consist of all other data definition items.
    run_sql_script 'clean_public_schema.sql'
    run_command %(time pg_restore --clean --if-exists --no-owner --section=pre-data --section=data -d #{etl_db_url} #{dump_filename})

    # STEP : anonymize and truncate all tables
    log_around('Anonymizing database') do
      @config.table_configs.each do |table_config|
        next unless ActiveRecord::Base.connection.table_exists?(table_config.table_name)
        Anonymizer::Table.new(table_config:).anonymize_records!
      end
    end

    # STEP : restore indexes
    run_command %(time pg_restore --clean --if-exists --no-owner --section=post-data -d #{etl_db_url} #{dump_filename})

    # delete the dump file as soon as possible
    FileUtils.rm(dump_filename) unless ENV['CACHE_DUMP']

    # workaround for a problematic column that we could also exclude
    # ERROR:  cannot insert a non-DEFAULT value into column "text_search_terms" (PG::GeneratedAlways)
    # DÉTAIL : Column "text_search_terms" is a generated column.
    run_sql_command %(ALTER TABLE users DROP COLUMN IF EXISTS text_search_terms CASCADE)

    # STEP : move from public to target schema
    target_schema = app
    run_sql_command %(DROP SCHEMA IF EXISTS #{target_schema} CASCADE;)
    run_sql_script 'clone_schema.sql' # loads the clone_schema function without calling it
    run_sql_command %(SELECT clone_schema('public', '#{target_schema}', TRUE);)
    run_sql_command %(GRANT USAGE ON SCHEMA #{target_schema} TO #{metabase_username};)
    run_sql_command %(GRANT SELECT ON ALL TABLES IN SCHEMA #{target_schema} TO #{metabase_username};)
    run_sql_script 'clean_public_schema.sql'
  end

  def dump_filename
    @dump_filename ||= "dump.#{app}.#{Time.now.strftime('%Y-%m-%d')}.pgsql.tar"
  end
end
