require "minitest/autorun"
require_relative "../lib/etl"

DB_BASE_URL = "postgresql://#{ENV.fetch("DB_USER", "adipasquale")}:#{ENV["DB_PASSWORD"]}@localhost"

class TestEtl < Minitest::Test

  def run_cmd(cmd)
    puts cmd
    system cmd
    puts ""
  end

  def run_sql(sql)
    run_cmd %Q(echo "#{sql}" | psql -d #{DB_BASE_URL}/postgres)
  end

  def setup
    run_sql "DROP DATABASE IF EXISTS rdv_sp_etl_test_source;"
    run_sql "DROP DATABASE IF EXISTS rdv_sp_etl_test_target;"
    run_sql "DROP ROLE IF EXISTS rdv_sp_etl_metabase_user;"

    run_sql "CREATE DATABASE rdv_sp_etl_test_source"
    # pg_dump --format tar --clean --no-privileges postgresql://localhost/lapin_development -f ../rdv-service-public-etl/tests/seeds_dump.pgsql
    seeds_dump_path = File.expand_path("seeds_dump.pgsql", File.dirname(__FILE__))
    run_cmd "pg_restore --no-owner -d #{DB_BASE_URL}/rdv_sp_etl_test_source #{seeds_dump_path}"

    run_sql "CREATE DATABASE rdv_sp_etl_test_target;"
    run_sql "CREATE ROLE rdv_sp_etl_metabase_user WITH LOGIN PASSWORD 'metabase_password';"
  end

  def test_something
    Etl.new(
      app: "rdv_solidarites",
      etl_db_url: "#{DB_BASE_URL}/rdv_sp_etl_test_target",
      rdv_db_url: "#{DB_BASE_URL}/rdv_sp_etl_test_source",
      config_path: File.expand_path("config.yml", File.dirname(__FILE__)),
      metabase_username: "rdv_sp_etl_metabase_user"
    ).run

    ActiveRecord::Base.establish_connection "postgresql://rdv_sp_etl_metabase_user:metabase_password@#{ENV.fetch("DB_HOST", "localhost")}/rdv_sp_etl_test_target"
    users_first_names = ActiveRecord::Base.connection.execute(
      Arel::Table.new("rdv_solidarites.users").project(:first_name).to_sql
    ).values.map(&:first).uniq
    assert_equal users_first_names, ["[valeur anonymisée]"]
  end
end
