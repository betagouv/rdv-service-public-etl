require "active_record"
require 'logger'
require 'uri'
require 'mkmf' # for find_executable

module Utils
  # ce log formatter évite de logger les mots de passes postgresql
  class SafeFormatter < Logger::Formatter
    PG_URL_REGEX = %r{(postgresql://[^:]+):[^@]+(@[^:/]+:\d+/[^ ]+)}

    def call(severity, time, progname, msg)
      msg = msg.gsub(PG_URL_REGEX) { "#{$1}:XXXXXX#{$2}" } if msg.is_a?(String)
      super(severity, time, progname, msg)
    end
  end

  def logger
    @logger ||= Logger.new(STDOUT, formatter: SafeFormatter.new)
  end

  def log_around(action)
    logger.debug "#{action} ..."
    yield
    logger.debug "✅ #{action} finished \n"
  end

  def run_command(command)
    log_around command do
      res = system(command)
      raise "Command failed" unless res
    end
  end

  def run_sql_command(command)
    log_around(command) { ActiveRecord::Base.connection.execute(command) }
  end

  def run_sql_script(filename)
    log_around "executing SQL script #{filename}" do
      path = File.expand_path(filename, File.dirname(__FILE__))
      ActiveRecord::Base.connection.execute(File.read(path))
    end
  end
end
