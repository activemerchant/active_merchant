module Braintree
  class AddOn < Modification

    def self.all
      Configuration.gateway.add_on.all
    end
  end
end
