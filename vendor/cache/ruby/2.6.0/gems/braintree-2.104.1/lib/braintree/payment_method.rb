module Braintree
  class PaymentMethod
    include BaseModule

    def self.create(*args)
      Configuration.gateway.payment_method.create(*args)
    end

    def self.create!(*args)
      Configuration.gateway.payment_method.create!(*args)
    end

    def self.find(*args)
      Configuration.gateway.payment_method.find(*args)
    end

    def self.update(*args)
      Configuration.gateway.payment_method.update(*args)
    end

    def self.update!(*args)
      Configuration.gateway.payment_method.update!(*args)
    end

    def self.delete(*args)
      Configuration.gateway.payment_method.delete(*args)
    end

    def self.grant(*args)
      Configuration.gateway.payment_method.grant(*args)
    end

    def self.revoke(*args)
      Configuration.gateway.payment_method.revoke(*args)
    end
  end
end
