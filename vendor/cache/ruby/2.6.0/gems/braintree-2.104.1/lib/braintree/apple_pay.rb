module Braintree
  class ApplePay
    include BaseModule # :nodoc:

    def initialize(gateway, attributes) # :nodoc:
      set_instance_variables_from_hash(attributes)
    end

    class << self
      protected :new
    end

    def self._new(*args) # :nodoc:
      self.new *args
    end

    def self.register_domain(domain)
      Configuration.gateway.apple_pay.register_domain(domain)
    end

    def self.unregister_domain(domain)
      Configuration.gateway.apple_pay.unregister_domain(domain)
    end

    def self.registered_domains
      Configuration.gateway.apple_pay.registered_domains
    end
  end
end
