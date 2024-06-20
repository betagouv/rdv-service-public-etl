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

db_url = URI.parse(ENV['DATABASE_URL_ETL'])
ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  encoding: "unicode",
  database: db_url.path[1..-1],
  username: db_url.user,
  password: db_url.password,
  host: db_url.hostname,
  port: db_url.port,
)

options = OpenStruct.new
OptionParser.new do |opts|
  opts.on('-a', '--app APP', %w[rdvi rdvsp]) { options.app = _1 }
  opts.on('-e', '--env ENV', %w[demo prod]) { options.env = _1 }
  opts.on('-s', '--schema [SCHEMA]', "sera par défaut le nom de l'app, mais peut être surchargé ici") { options.schema = _1 }
end.parse!

if find_executable('dbclient-fetcher')
  puts ""
  puts "Install additional tools to interact with the database:"
  puts "dbclient-fetcher pgsql"
  puts ""
  exec("dbclient-fetcher pgsql")
end

available_apps = {
  "rdvi" => {
    "demo" => {
      scalingo_app: "rdv-insertion-demo",
      db_url: ENV['DATABASE_URL_RDVI_DEMO']
    },
    "prod" => {
      scalingo_app: "rdv-insertion-production",
      db_url: ENV['DATABASE_URL_RDVI_PROD']
    }
  },
  "rdvsp" => {
    "demo" => {
      scalingo_app: "demo-rdv-solidarites",
      db_url: ENV['DATABASE_URL_RDVSP_DEMO']
    },
    "prod" => {
      scalingo_app: "production-rdv-solidarites",
      db_url: ENV['DATABASE_URL_RDVSP_PROD']
    }
  }
}

# schema_name = options.schema || options.app
scalingo_app=available_apps[options.app][options.env][:scalingo_app]
rdv_db_url=available_apps[options.app][options.env][:db_url]

date_s = Time.now.strftime("%Y-%m-%d")
dump_filename="dump.#{scalingo_app}.#{date_s}.pgsql"

def run_command(command)
  puts "\nRunning command: #{command}"
  system(command)
  puts ""
end

run_command("""
  pg_dump --clean --if-exists --no-owner --no-privileges \
    --format tar \
    --exclude-table versions \
    -f #{dump_filename} \
    #{rdv_db_url}
""")

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

Anonymizer::Runner.new(options.app, options.schema).run
