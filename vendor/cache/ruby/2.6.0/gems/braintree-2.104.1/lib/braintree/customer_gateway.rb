module Braintree
  class CustomerGateway # :nodoc:
    include BaseModule

    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def all
      response = @config.http.post("#{@config.base_merchant_path}/customers/advanced_search_ids")
      ResourceCollection.new(response) { |ids| _fetch_customers(CustomerSearch.new, ids) }
    end

    def create(attributes = {})
      Util.verify_keys(CustomerGateway._create_signature, attributes)
      _do_create "/customers", :customer => attributes
    end

    def create!(*args)
      return_object_or_raise(:customer) { create(*args) }
    end

    # Deprecated
    def create_customer_url
      "#{@config.base_merchant_url}/customers/all/create_via_transparent_redirect_request"
    end

    # Deprecated
    def create_from_transparent_redirect(query_string)
      params = @gateway.transparent_redirect.parse_and_validate_query_string query_string
      _do_create("/customers/all/confirm_transparent_redirect_request", :id => params[:id])
    end

    def delete(customer_id)
      @config.http.delete("#{@config.base_merchant_path}/customers/#{customer_id}")
      SuccessfulResult.new
    end

    def find(customer_id, options = {})
      raise ArgumentError, "customer_id contains invalid characters" unless customer_id.to_s =~ /\A[\w-]+\z/
      raise ArgumentError, "customer_id cannot be blank" if customer_id.nil?|| customer_id.to_s.strip == ""

      query_params = options[:association_filter_id].nil? ? "" : "?association_filter_id=#{options[:association_filter_id]}"
      response = @config.http.get("#{@config.base_merchant_path}/customers/#{customer_id}#{query_params}")
      Customer._new(@gateway, response[:customer])
    rescue NotFoundError
      raise NotFoundError, "customer with id #{customer_id.inspect} not found"
    end

    def search(&block)
      search = CustomerSearch.new
      block.call(search) if block

      response = @config.http.post("#{@config.base_merchant_path}/customers/advanced_search_ids", {:search => search.to_hash})
      ResourceCollection.new(response) { |ids| _fetch_customers(search, ids) }
    end

    def transactions(customer_id, options = {})
      response = @config.http.post("#{@config.base_merchant_path}/customers/#{customer_id}/transaction_ids")
      ResourceCollection.new(response) { |ids| _fetch_transactions(customer_id, ids) }
    end

    def update(customer_id, attributes)
      Util.verify_keys(CustomerGateway._update_signature, attributes)
      _do_update(:put, "/customers/#{customer_id}", :customer => attributes)
    end

    def update!(*args)
      return_object_or_raise(:customer) { update(*args) }
    end

    # Deprecated
    def update_customer_url
      warn "[DEPRECATED] Customer.update_customer_url is deprecated. Please use TransparentRedirect.url"
      "#{@config.base_merchant_url}/customers/all/update_via_transparent_redirect_request"
    end

    # Deprecated
    def update_from_transparent_redirect(query_string)
      params = @gateway.transparent_redirect.parse_and_validate_query_string(query_string)
      _do_update(:post, "/customers/all/confirm_transparent_redirect_request", :id => params[:id])
    end

    def self._create_signature # :nodoc:
      credit_card_signature = CreditCardGateway._create_signature - [:customer_id]
      paypal_account_signature = PayPalAccountGateway._create_nested_signature
      paypal_options_shipping_signature = AddressGateway._shared_signature
      options = [
        :paypal => [
          :payee_email,
          :order_id,
          :custom_field,
          :description,
          :amount,
          {:shipping => paypal_options_shipping_signature}
        ],
      ]
      [
        :company, :email, :fax, :first_name, :id, :last_name, :phone, :website,
        :device_data, :payment_method_nonce,
        {:risk_data => [:customer_browser, :customer_ip]},
        {:credit_card => credit_card_signature},
        {:paypal_account => paypal_account_signature},
        {:options => options},
        {:custom_fields => :_any_key_}
      ]
    end

    def _do_create(path, params=nil) # :nodoc:
      response = @config.http.post("#{@config.base_merchant_path}#{path}", params)
      if response[:customer]
        SuccessfulResult.new(:customer => Customer._new(@gateway, response[:customer]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise "expected :customer or :api_error_response"
      end
    end

    def _do_update(http_verb, path, params) # :nodoc:
      response = @config.http.send(http_verb, "#{@config.base_merchant_path}#{path}", params)
      if response[:customer]
        SuccessfulResult.new(:customer => Customer._new(@gateway, response[:customer]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :customer or :api_error_response"
      end
    end

    def _fetch_customers(search, ids) # :nodoc:
      search.ids.in ids
      response = @config.http.post("#{@config.base_merchant_path}/customers/advanced_search", {:search => search.to_hash})
      attributes = response[:customers]
      Util.extract_attribute_as_array(attributes, :customer).map { |attrs| Customer._new(@gateway, attrs) }
    end

    def _fetch_transactions(customer_id, ids) # :nodoc:
      response = @config.http.post("#{@config.base_merchant_path}/customers/#{customer_id}/transactions", :search => {:ids => ids})
      attributes = response[:credit_card_transactions]
      Util.extract_attribute_as_array(attributes, :transaction).map do |transaction_attributes|
        Transaction._new @gateway, transaction_attributes
      end
    end

    def self._update_signature # :nodoc:
      credit_card_signature = CreditCardGateway._update_signature - [:customer_id]
      credit_card_options = credit_card_signature.find { |item| item.respond_to?(:keys) && item.keys == [:options] }
      credit_card_options[:options] << :update_existing_token
      paypal_options_shipping_signature = AddressGateway._shared_signature
      options = [
        :paypal => [
          :payee_email,
          :order_id,
          :custom_field,
          :description,
          :amount,
          {:shipping => paypal_options_shipping_signature}
        ],
      ]
      [
        :company, :email, :fax, :first_name, :id, :last_name, :phone, :website,
        :device_data, :payment_method_nonce, :default_payment_method_token,
        {:credit_card => credit_card_signature},
        {:options => options},
        {:custom_fields => :_any_key_}
      ]
    end
  end
end
