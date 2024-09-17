require "minitest/autorun"
require_relative "../lib/etl"

class TestEtl < Minitest::Test
  def setup
    system "dropdb --if-exists rdv_sp_etl_test_source"
    system "dropdb --if-exists rdv_sp_etl_test_target"
    system "dropuser --if-exists rdv_sp_etl_metabase_user"

    system "createdb rdv_sp_etl_test_source"
    # pg_dump --format tar --clean --no-privileges postgresql://localhost/lapin_development -f ../rdv-service-public-etl/tests/seeds_dump.pgsql
    seeds_dump_path = File.expand_path("seeds_dump.pgsql", File.dirname(__FILE__))
    system "pg_restore --no-owner -d postgresql://localhost/rdv_sp_etl_test_source #{seeds_dump_path}"
    system "createdb rdv_sp_etl_test_target"
    system %Q(echo "CREATE ROLE rdv_sp_etl_metabase_user WITH LOGIN PASSWORD 'metabase_password'" | psql -d rdv_sp_etl_test_target;)
  end

  def test_something
    Etl.new(
      app: "rdvs",
      etl_db_url: "postgresql://localhost/rdv_sp_etl_test_target",
      rdv_db_url: "postgresql://localhost/rdv_sp_etl_test_source",
      config_path: File.expand_path("config.yml", File.dirname(__FILE__)),
      metabase_username: "rdv_sp_etl_metabase_user"
    ).run

    ActiveRecord::Base.establish_connection "postgresql://rdv_sp_etl_metabase_user:metabase_password@localhost/rdv_sp_etl_test_target"
    users_first_names = ActiveRecord::Base.connection.execute(
      Arel::Table.new("rdvs.users").project(:first_name).to_sql
    ).values.map(&:first).uniq
    assert_equal users_first_names, ["[valeur anonymisée]"]
  end
end
