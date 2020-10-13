module Braintree
  class Discount < Modification

    def self.all
      Configuration.gateway.discount.all
    end
  end
end
