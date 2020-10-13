module Braintree
  class TestTransaction < Transaction
    def self.settle(transaction_id)
      Configuration.gateway.testing.settle(transaction_id)
    end

    def self.settlement_confirm(transaction_id)
      Configuration.gateway.testing.settlement_confirm(transaction_id)
    end

    def self.settlement_decline(transaction_id)
      Configuration.gateway.testing.settlement_decline(transaction_id)
    end

    def self.settlement_pending(transaction_id)
      Configuration.gateway.testing.settlement_pending(transaction_id)
    end
  end
end
