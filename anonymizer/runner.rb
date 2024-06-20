module Anonymizer
  class Runner
    def initialize(service, schema)
      @service = service
      @schema = schema
    end

    def run
      Anonymizer::Core.anonymize_all_data!(service:, schema:)

      if service == "rdvsp"
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

    attr_reader :service, :schema
  end
end
