module Braintree
  class PaymentMethodGateway # :nodoc:
    include BaseModule

    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def create(attributes)
      Util.verify_keys(PaymentMethodGateway._create_signature, attributes)
      _do_create("/payment_methods", :payment_method => attributes)
    end

    def create!(*args)
      return_object_or_raise(:payment_method) { create(*args) }
    end

    def _do_create(path, params=nil) # :nodoc:
      response = @config.http.post("#{@config.base_merchant_path}#{path}", params)

      if response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      elsif response
        SuccessfulResult.new(:payment_method => PaymentMethodParser.parse_payment_method(@gateway, response))
      else
        raise UnexpectedError, "expected :payment_method or :api_error_response"
      end
    end

    def delete(token, options = {})
      Util.verify_keys(PaymentMethodGateway._delete_signature, options)
      query_param = "?" + Util.hash_to_query_string(options) if not options.empty?
      @config.http.delete("#{@config.base_merchant_path}/payment_methods/any/#{token}#{query_param}")
      SuccessfulResult.new
    end

    def find(token)
      raise ArgumentError if token.nil? || token.to_s.strip == ""
      response = @config.http.get("#{@config.base_merchant_path}/payment_methods/any/#{token}")
      if response.has_key?(:credit_card)
        CreditCard._new(@gateway, response[:credit_card])
      elsif response.has_key?(:paypal_account)
        PayPalAccount._new(@gateway, response[:paypal_account])
      elsif response[:coinbase_account]
        SuccessfulResult.new(:payment_method => CoinbaseAccount._new(@gateway, response[:coinbase_account]))
      elsif response.has_key?(:us_bank_account)
        UsBankAccount._new(@gateway, response[:us_bank_account])
      elsif response.has_key?(:europe_bank_account)
        EuropeBankAccount._new(@gateway, response[:europe_bank_account])
      elsif response.has_key?(:apple_pay_card)
        ApplePayCard._new(@gateway, response[:apple_pay_card])
      elsif response.has_key?(:android_pay_card)
        # NEXT_MAJOR_VERSION rename Android Pay to Google Pay
        AndroidPayCard._new(@gateway, response[:android_pay_card])
      elsif response.has_key?(:venmo_account)
        VenmoAccount._new(@gateway, response[:venmo_account])
      else
        UnknownPaymentMethod._new(@gateway, response)
      end
    rescue NotFoundError
      raise NotFoundError, "payment method with token #{token.inspect} not found"
    end

    def update(token, attributes)
      Util.verify_keys(PaymentMethodGateway._update_signature, attributes)
      _do_update(:put, "/payment_methods/any/#{token}", :payment_method => attributes)
    end

    def update!(*args)
      return_object_or_raise(:payment_method) { update(*args) }
    end

    def _do_update(http_verb, path, params) # :nodoc:
      response = @config.http.send(http_verb, "#{@config.base_merchant_path}#{path}", params)
      if response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      elsif response
        SuccessfulResult.new(:payment_method => PaymentMethodParser.parse_payment_method(@gateway, response))
      else
        raise UnexpectedError, "expected :payment_method or :api_error_response"
      end
    end

    def grant(token, options = {})
      raise ArgumentError if token.nil? || token.to_s.strip == ""
      if  options.class == Hash
        grant_options = options
      elsif [true, false].include?(options)
        grant_options = { :allow_vaulting => options }
      else
        raise ArgumentError
      end

      _do_grant(
        "/payment_methods/grant",
        :payment_method => {
          :shared_payment_method_token => token,
        }.merge(grant_options)
      )
    rescue NotFoundError
      raise NotFoundError, "payment method with token #{token.inspect} not found"
    end

    def _do_grant(path, params=nil)
      response = @config.http.post("#{@config.base_merchant_path}#{path}", params)
      if response[:payment_method_nonce]
        SuccessfulResult.new(:payment_method_nonce => PaymentMethodNonce._new(@gateway, response[:payment_method_nonce]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :payment_method_nonce or :api_error_response"
      end
    end

    def revoke(token)
      raise ArgumentError if token.nil? || token.to_s.strip == ""

      _do_revoke(
        "/payment_methods/revoke",
        :payment_method => {
          :shared_payment_method_token => token
        }
      )
    rescue NotFoundError
      raise NotFoundError, "payment method with token #{token.inspect} not found"
    end

    def _do_revoke(path, params=nil)
      response = @config.http.post("#{@config.base_merchant_path}#{path}", params)
      if response[:success]
        SuccessfulResult.new
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :success or :api_error_response"
      end
    end

    def self._create_signature # :nodoc:
      _signature(:create)
    end

    def self._update_signature # :nodoc:
      _signature(:update)
    end

    def self._delete_signature # :nodoc:
      [:revoke_all_grants]
    end

    def self._signature(type) # :nodoc:
      billing_address_params = AddressGateway._shared_signature
      paypal_options_shipping_signature = AddressGateway._shared_signature
      options = [
        :make_default, :verification_merchant_account_id, :verify_card, :venmo_sdk_session,
        :verification_amount, :us_bank_account_verification_method,
        :verification_account_type,
        :paypal => [
          :payee_email,
          :order_id,
          :custom_field,
          :description,
          :amount,
          {:shipping => paypal_options_shipping_signature}
        ],
      ]
      signature = [
        :billing_address_id, :cardholder_name, :cvv, :device_session_id, :expiration_date,
        :expiration_month, :expiration_year, :number, :token, :venmo_sdk_payment_method_code,
        :device_data, :fraud_merchant_id, :payment_method_nonce,
        {:options => options},
        {:billing_address => billing_address_params}
      ]
      signature << {
        :three_d_secure_pass_thru => [
          :eci_flag,
          :cavv,
          :xid,
          :three_d_secure_version,
          :authentication_response,
          :directory_response,
          :cavv_algorithm,
          :ds_transaction_id,
        ]
      }

      case type
      when :create
        options << :fail_on_duplicate_payment_method
        signature << :customer_id
        signature << :paypal_refresh_token
        # NEXT_MAJOR_VERSION remove this from the signature
        signature << :paypal_vault_without_upgrade
      when :update
        billing_address_params << {:options => [:update_existing]}
      else
        raise ArgumentError
      end

      return signature
    end
  end
end
