module Braintree
  class SettlementBatchSummary
    include BaseModule
    
    attr_reader :records

    def self.generate(settlement_date, group_by_custom_field = nil)
      criteria = { :settlement_date => settlement_date }
      criteria.merge!({:group_by_custom_field => group_by_custom_field}) if group_by_custom_field
      Configuration.gateway.settlement_batch_summary.generate(criteria)
    end

    def initialize(gateway, attributes)
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
    end

    class << self
      protected :new
      def _new(*args)
        self.new(*args)
      end
    end
  end
end
