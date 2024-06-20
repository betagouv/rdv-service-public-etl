require 'optparse'
require 'ostruct'
require 'mkmf'
require "active_support/all"
require "zeitwerk"
require "active_record"
require 'dotenv'
require 'tempfile'

Dotenv.load

loader = Zeitwerk::Loader.new
loader.push_dir(".")
loader.setup

def run_command(command)
  puts "\nRunning command: #{command}"
  res = system(command)
  # raise "Command failed" unless res
  puts ""
end

def relative_path(path)
  File.expand_path(path, File.dirname(__FILE__))
end

db_url = URI.parse(ENV['ETL_DATABASE_URL'])
ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  encoding: "unicode",
  database: db_url.path[1..-1],
  username: db_url.user,
  password: db_url.password,
  host: db_url.hostname,
  port: db_url.port,
)

APPS_ARGS = %w[rdv_insertion rdv_solidarites].freeze

options = OpenStruct.new
OptionParser.new do |opts|
  opts.on('-a', '--app APP', APPS_ARGS) { options.app = _1 }
  opts.on('--skip-restore') { options.skip_restore = true }
end.parse!

raise "invalid app" if APPS_ARGS.exclude?(options.app)

if find_executable('dbclient-fetcher')
  puts ""
  puts "Install additional tools to interact with the database:"
  puts "dbclient-fetcher pgsql"
  puts ""
  exec("dbclient-fetcher pgsql")
end

rdv_scalingo_app=ENV["#{options.app.upcase}_SCALINGO_APP"]
rdv_db_url=ENV["#{options.app.upcase}_DATABASE_URL"]

date_s = Time.now.strftime("%Y-%m-%d")
dump_filename="dump.#{rdv_scalingo_app}.#{date_s}.pgsql.tar"

unless File.exist?(dump_filename)
  puts "Dumping the database..."
  run_command(
    <<~SH.strip_heredoc
      pg_dump --clean --no-owner --no-privileges \
        --format tar \
        --exclude-table versions \
        --exclude-table receipts \
        -f #{dump_filename} \
        #{rdv_db_url}
    SH
  )
  puts "✅ Database dumped to #{dump_filename}"
end

unless options.skip_restore
  puts "Restoring the database..."
  run_command(%Q(pg_restore --clean --if-exists --no-owner -d #{ENV["ETL_DATABASE_URL"]} #{dump_filename}))
  puts "✅ Database restored"
end

# TODO: remove this when fixed upstream
puts "Setting default value for api_calls.raw_http..."
run_command(
  <<~SH.strip_heredoc
    psql -d #{ENV["ETL_DATABASE_URL"]} \
    -c "ALTER TABLE api_calls ALTER COLUMN raw_http SET DEFAULT '{}'"
  SH
)
puts "✅ Default value set"

service_name = {
  "rdv_insertion" => "rdv_insertion",
  "rdv_solidarites" => "rdv_service_public",
  "rdv_service_public" => "rdv_service_public",
}[options.app]

puts "Anonymizing #{service_name}..."
Anonymizer::Runner.new(service_name).run
puts "✅ Anonymization done"

puts "Copying everything from public schema to #{options.app}..."

copy_schema_sql = File.read(relative_path("copy_schema.sql.template"))
copy_schema_sql = copy_schema_sql.gsub("·new_schema_name·", options.app)
Tempfile.create do |f|
  f.write(copy_schema_sql)
  f.rewind
  run_command(%Q(psql -d #{ENV["ETL_DATABASE_URL"]} < #{f.path}))
end
puts "✅ moved everything from public schema to #{options.app}"

puts "Cleaning public schema..."
run_command("psql -d #{ENV["ETL_DATABASE_URL"]} < #{relative_path("clean_public_schema.sql")}")
puts "✅ public schema cleaned"
