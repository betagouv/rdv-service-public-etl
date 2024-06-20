# bundle exec ruby main.rb --app rdvi --env demo --schema public

require 'optparse'
require 'ostruct'
require 'mkmf'
require "active_support/all"
require "zeitwerk"
require "active_record"
require 'dotenv'

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
  opts.on('-s', '--schema [SCHEMA]', "sera par défaut le nom de l'app, mais peut être surchargé ici") { options.schema = _1 }
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

# schema_name = options.schema || options.app
rdv_scalingo_app=ENV["#{options.app.upcase}_SCALINGO_APP"]
rdv_db_url=ENV["#{options.app.upcase}_DATABASE_URL"]

date_s = Time.now.strftime("%Y-%m-%d")
dump_filename="dump.#{rdv_scalingo_app}.#{date_s}.pgsql.tar"

unless File.exist?(dump_filename)
  puts "Dumping the database..."
  run_command("""
    pg_dump --clean --no-owner --no-privileges \
      --format tar \
      --exclude-table versions \
      --exclude-table receipts \
      -f #{dump_filename} \
      #{rdv_db_url}
  """)
  puts "✅ Database dumped to #{dump_filename}"
end

unless options.skip_restore
  puts "Restoring the database..."
  run_command("""
    pg_restore --clean --verbose \
      -d #{ENV["ETL_DATABASE_URL"]} \
      #{dump_filename}
  """)
  puts "✅ Database restored"
end


# if find_executable('scalingo')
#   puts "✅ scalingo CLI is already installed"
# else
#   puts ''
#   puts 'Install the Scalingo CLI tool in the container:'
#   puts 'install-scalingo-cli'
#   puts ''
#   exec('install-scalingo-cli')
#   puts "✅ scalingo CLI is now installed"
# end

# exec("main1.sh")

service_name = {
  "rdv_insertion" => "rdv_insertion",
  "rdv_solidarites" => "rdv_service_public",
  "rdv_service_public" => "rdv_service_public",
}[options.app]

Anonymizer::Runner.new(service_name, options.schema).run
