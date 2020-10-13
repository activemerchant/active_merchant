module Braintree
  class AddressGateway # :nodoc
    include BaseModule

    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def create(attributes)
      Util.verify_keys(AddressGateway._create_signature, attributes)
      unless attributes[:customer_id]
        raise ArgumentError, "Expected hash to contain a :customer_id"
      end
      unless attributes[:customer_id] =~ /\A[0-9A-Za-z_-]+\z/
        raise ArgumentError, ":customer_id contains invalid characters"
      end
      response = @config.http.post("#{@config.base_merchant_path}/customers/#{attributes.delete(:customer_id)}/addresses", :address => attributes)
      if response[:address]
        SuccessfulResult.new(:address => Address._new(@gateway, response[:address]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :address or :api_error_response"
      end
    end

    def create!(*args)
      return_object_or_raise(:address) { create(*args) }
    end

    def delete(customer_or_customer_id, address_id)
      customer_id = _determine_customer_id(customer_or_customer_id)
      @config.http.delete("#{@config.base_merchant_path}/customers/#{customer_id}/addresses/#{address_id}")
      SuccessfulResult.new
    end

    def find(customer_or_customer_id, address_id)
      customer_id = _determine_customer_id(customer_or_customer_id)
      raise ArgumentError if address_id.nil? || address_id.to_s.strip == ""
      response = @config.http.get("#{@config.base_merchant_path}/customers/#{customer_id}/addresses/#{address_id}")
      Address._new(@gateway, response[:address])
    rescue NotFoundError
      raise NotFoundError, "address for customer #{customer_id.inspect} with id #{address_id.inspect} not found"
    end

    def update(customer_or_customer_id, address_id, attributes)
      Util.verify_keys(AddressGateway._update_signature, attributes)
      customer_id = _determine_customer_id(customer_or_customer_id)
      response = @config.http.put("#{@config.base_merchant_path}/customers/#{customer_id}/addresses/#{address_id}", :address => attributes)
      if response[:address]
        SuccessfulResult.new(:address => Address._new(@gateway, response[:address]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :address or :api_error_response"
      end
    end

    def update!(*args)
      return_object_or_raise(:address) { update(*args) }
    end

    def _determine_customer_id(customer_or_customer_id) # :nodoc:
      customer_id = customer_or_customer_id.is_a?(Customer) ? customer_or_customer_id.id : customer_or_customer_id
      unless customer_id =~ /\A[\w_-]+\z/
        raise ArgumentError, "customer_id contains invalid characters"
      end
      customer_id
    end

    def self._create_signature # :nodoc:
      _shared_signature + [:customer_id]
    end

    def self._shared_signature # :nodoc:
      [:company, :country_code_alpha2, :country_code_alpha3, :country_code_numeric,
        :country_name, :extended_address, :first_name, :last_name, :locality, :phone_number,
        :postal_code, :region, :street_address]
    end

    def self._update_signature # :nodoc:
      _create_signature
    end
  end
end

