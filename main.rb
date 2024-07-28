require "active_support/all"
require 'optparse'
require 'dotenv'

require_relative "etl"

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
  "rdv_mairie" => ENV["ANONYMIZER_CONFIG_RDV_SERVICE_PUBLIC_URL"],
}[app]

etl_db_url = ENV['ETL_DATABASE_URL']
rdv_db_url = ENV["#{app.upcase}_DATABASE_URL"]

etl_db_url_parsed, rdv_db_url_parsed = [etl_db_url, rdv_db_url].map { URI.parse(_1) }



begin
  # to avoid logging sensitive passwords, we extract them from env vars into a .pgpass file
  File.open "#{ENV['HOME']}/.pgpass", "w" do |f|
    f.write(
      [etl_db_url_parsed, rdv_db_url_parsed]
        .map { [_1.hostname, _1.port, _1.path[1..-1], _1.user, _1.password].join(":") }
        .join("\n")
    )
    f.chmod(0600)
  end

  etl_db_url_safe, rdv_db_url_safe = [etl_db_url_parsed, rdv_db_url_parsed].map {  |url| url.dup.tap { _1.password = nil }.to_s }

  Etl.new(app:, etl_db_url: etl_db_url_safe, rdv_db_url: rdv_db_url_safe, config_url:, use_cache:, skip_restore:).run
ensure
  FileUtils.rm_f("#{ENV['HOME']}/.pgpass")
end
