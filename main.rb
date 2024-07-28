require 'optparse'
require 'ostruct'
require 'mkmf'
require "active_support/all"
require "active_record"
require 'dotenv'
require 'tempfile'
require 'anonymizer'

Dotenv.load

def run_command(command)
  puts "\nRunning command: #{command}"
  res = system(command)
  raise "Command failed" unless res
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

def run_sql_command(command)
  ActiveRecord::Base.connection.execute(command)
end

def run_sql_script(path)
  run_sql_command(File.read(path))
end

APPS_ARGS = %w[rdv_insertion rdv_solidarites rdv_mairie].freeze

options = OpenStruct.new
OptionParser.new do |opts|
  opts.on('-a', '--app APP', APPS_ARGS) { options.app = _1 }
  opts.on('--use-cache') { options.use_cache = true }
  opts.on('--skip-restore') { options.skip_restore = true }
end.parse!

raise "invalid app" if APPS_ARGS.exclude?(options.app)

if find_executable('dbclient-fetcher')
  puts ""
  puts "Install additional tools to interact with the database:"
  puts "dbclient-fetcher pgsql"
  puts ""
  exec "dbclient-fetcher pgsql"
end

# rdv_scalingo_app=ENV["#{options.app.upcase}_SCALINGO_APP"]
rdv_db_url=ENV["#{options.app.upcase}_DATABASE_URL"]
dump_filename="dump.#{options.app}.#{Time.now.strftime("%Y-%m-%d")}.pgsql.tar"

if !File.exist?(dump_filename) || !options.use_cache
  puts "Dumping the database..."

  excluded_tables = %w[
    versions
    good_jobs
    good_job_executions
    good_job_settings
    good_job_batches
    good_job_processes
  ]

  run_command(
    <<~SH.strip_heredoc
      pg_dump --clean --no-owner --no-privileges \
        --format tar \
        #{excluded_tables.map { "--exclude-table #{_1}"}.join(" ")} \
        -f #{dump_filename} \
        #{rdv_db_url}
    SH
  )
  puts "✅ Database dumped to #{dump_filename}"
end

unless options.skip_restore
  puts "Cleaning public schema..."
  run_sql_script(relative_path("clean_public_schema.sql"))
  puts "✅ public schema cleaned"

  puts "Restoring the database..."
  run_command(%Q(pg_restore --clean --if-exists --no-owner --section=pre-data --section=data -d #{db_url} #{dump_filename}))
  puts "✅ Database restored"
end

config_url = {
  "rdv_insertion" => ENV["ANONYMIZER_CONFIG_RDV_INSERTION_URL"],
  "rdv_solidarites" => ENV["ANONYMIZER_CONFIG_RDV_SERVICE_PUBLIC_URL"],
  "rdv_mairie" => ENV["ANONYMIZER_CONFIG_RDV_SERVICE_PUBLIC_URL"],
}[options.app]

puts "downloading #{config_url} to ./config.yml ..."
run_command("curl -o config.yml \"#{config_url}\"")
puts "done !"

puts "Anonymizing database..."
Anonymizer.anonymize_all_data!(config: Anonymizer::Config.new(YAML.safe_load(File.read("config.yml"))))
puts "✅ Anonymization done"

puts "removing column users.text_search_terms"
run_sql_command(%Q(ALTER TABLE users DROP COLUMN IF EXISTS text_search_terms))
puts "✅ column removed"

target_schema_name = options.app
run_sql_command(%Q(DROP SCHEMA IF EXISTS #{target_schema_name} CASCADE;))

puts "Copying everything from public schema to #{target_schema_name}..."
run_sql_script(relative_path("clone_schema.sql"))
run_sql_command(%Q(SELECT clone_schema('public', '#{target_schema_name}', TRUE);))
puts "✅ moved everything from public schema to #{target_schema_name}"

puts "Cleaning public schema..."
run_sql_script(relative_path("clean_public_schema.sql"))
puts "✅ public schema cleaned"
