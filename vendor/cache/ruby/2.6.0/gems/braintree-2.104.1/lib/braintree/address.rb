module Braintree
  class Address
    include BaseModule # :nodoc:

    attr_reader :company
    attr_reader :country_code_alpha2
    attr_reader :country_code_alpha3
    attr_reader :country_code_numeric
    attr_reader :country_name
    attr_reader :created_at
    attr_reader :customer_id
    attr_reader :extended_address
    attr_reader :first_name
    attr_reader :id
    attr_reader :last_name
    attr_reader :locality
    attr_reader :postal_code
    attr_reader :region
    attr_reader :street_address
    attr_reader :updated_at

    def self.create(*args)
      Configuration.gateway.address.create(*args)
    end

    def self.create!(*args)
      Configuration.gateway.address.create!(*args)
    end

    def self.delete(*args)
      Configuration.gateway.address.delete(*args)
    end

    def self.find(*args)
      Configuration.gateway.address.find(*args)
    end

    def self.update(*args)
      Configuration.gateway.address.update(*args)
    end

    def self.update!(*args)
      Configuration.gateway.address.update!(*args)
    end

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
    end

    def ==(other) # :nodoc:
      return false unless other.is_a?(Address)
      id == other.id && customer_id == other.customer_id
    end

    # Deprecated. Use Braintree::Address.delete
    def delete
      warn "[DEPRECATED] delete as an instance method is deprecated. Please use Address.delete"
      @gateway.address.delete(customer_id, self.id)
    end

    # Deprecated. Use Braintree::Address.update
    def update(attributes)
      warn "[DEPRECATED] update as an instance method is deprecated. Please use Address.update"
      result = @gateway.address.update(customer_id, id, attributes)
      if result.success?
        copy_instance_variables_from_object result.address
      end
      result
    end

    # Deprecated. Use Braintree::Address.update!
    def update!(attributes)
      warn "[DEPRECATED] update! as an instance method is deprecated. Please use Address.update!"
      return_object_or_raise(:address) { update(attributes) }
    end

    class << self
      protected :new
    end

    def self._new(*args) # :nodoc:
      self.new *args
    end
  end
end
