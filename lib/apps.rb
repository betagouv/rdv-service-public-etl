class Apps
  class << self
    @apps = {}

    def register(name:, config_url:, source_url_env_var:)
      @apps[name] = OpenStruct.new(config_url:, source_url_env_var:)
    end

    def get(name)
      @apps[name] || raise "invalid app"
    end

    def valid_names
      @apps.keys
    end
  end
end

Apps.register(
  name: "rdvi",
  config_url: "https://raw.githubusercontent.com/betagouv/rdv-insertion/staging/config/anonymizer.yml",
  source_url_env_var: "RDV_INSERTION_DB_URL",
)

Apps.register(
  name: "rdvs",
  config_url: "https://raw.githubusercontent.com/betagouv/rdv-service-public/production/config/anonymizer.yml",
  source_url_env_var: "RDV_SOLIDARITES_DB_URL"
)

Apps.register(
  name: "rdvsp",
  config_url: "https://raw.githubusercontent.com/betagouv/rdv-service-public/production/config/anonymizer.yml",
  source_url_env_var: "RDV_SERVICE_PUBLIC_DB_URL"
)


