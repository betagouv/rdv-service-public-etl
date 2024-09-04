require "active_record"
require 'logger'
require 'uri'

module Utils
  class SafeFormatter < Logger::Formatter
    PG_URL_REGEX = %r{(postgresql://[^:]+):[^@]+(@[^:/]+:\d+/[^ ]+)}

    def call(severity, time, progname, msg)
      msg = msg.gsub(PG_URL_REGEX) { "#{$1}:XXXXXX#{$2}" } if msg.is_a?(String)
      super(severity, time, progname, msg)
    end
  end

  def run_command(command)
    log_around command do
      res = system(command)
      raise "Command failed" unless res
    end
  end

  def relative_path(path)
    File.expand_path(path, File.dirname(__FILE__))
  end

  def connect_active_record(db_url)
    parsed = URI.parse(db_url)
    ActiveRecord::Base.establish_connection(
      adapter: "postgresql",
      encoding: "unicode",
      database: parsed.path[1..-1],
      username: parsed.user,
      password: parsed.password,
      host: parsed.hostname,
      port: parsed.port,
    )
    ActiveRecord::Base.connection # triggers connection
  rescue ActiveRecord::DatabaseConnectionError => e
    logger.error "could not connect to ETL database #{db_url} : #{e.message}"
    exit 1
  end

  def run_sql_command(command)
    log_around(command) { ActiveRecord::Base.connection.execute(command) }
  end

  def run_sql_script(filename)
    log_around "executing SQL script #{filename}" do
      ActiveRecord::Base.connection.execute((File.read(relative_path(filename))))
    end
  end

  def install_dbclient_fetcher
    return unless find_executable('dbclient-fetcher')

    logger.debug ""
    logger.debug "Install additional tools to interact with the database:"
    logger.debug "dbclient-fetcher pgsql"
    logger.debug ""
    system "dbclient-fetcher pgsql"
  end

  def logger
    @logger ||= Logger.new(STDOUT, formatter: SafeFormatter.new)
  end

  def log_around(action)
    logger.debug "#{action} ..."
    yield
    logger.debug "✅ #{action} finished \n"
  end
end
