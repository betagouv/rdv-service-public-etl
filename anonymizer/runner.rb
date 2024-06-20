class User < ActiveRecord::Base; end
class Agent < ActiveRecord::Base; end
class Prescripteur < ActiveRecord::Base; end
class Receipt < ActiveRecord::Base; end

module Anonymizer
  class Runner
    def initialize(service, schema)
      @service = service
      raise "invalid app" if %w[rdv_insertion rdv_service_public].exclude?(service)
      @schema = schema
    end

    def run
      Anonymizer::Core.anonymize_all_data!(service:, schema:)

      if service == "rdv_service_public"
        # Sanity checks
        if User.where.not(last_name: "[valeur anonymisée]").any?
          raise "Certains usagers n'ont pas été anonymisés !"
        end

        if Agent.where.not(last_name: "[valeur anonymisée]").any?
          raise "Certains agents n'ont pas été anonymisés !"
        end

        if Prescripteur.where.not(first_name: "[valeur anonymisée]").any?
          raise "Certains prescripteurs n'ont pas été anonymisés !"
        end

        if Receipt.where.not(content: "[valeur anonymisée]").any?
          raise "Certains receipts n'ont pas été anonymisés !"
        end
      end
    end

    private

    attr_accessor :service, :schema
  end
end
