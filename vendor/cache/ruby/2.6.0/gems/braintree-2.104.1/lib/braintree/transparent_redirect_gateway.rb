module Braintree
  class TransparentRedirectGateway # :nodoc
    TransparentRedirectKeys = [:redirect_url] # :nodoc:
    CreateCustomerSignature = TransparentRedirectKeys + [{:customer => CustomerGateway._create_signature}] # :nodoc:
    UpdateCustomerSignature = TransparentRedirectKeys + [:customer_id, {:customer => CustomerGateway._update_signature}] # :nodoc:
    TransactionSignature = TransparentRedirectKeys + [{:transaction => TransactionGateway._create_signature}] # :nodoc:
    CreateCreditCardSignature = TransparentRedirectKeys + [{:credit_card => CreditCardGateway._create_signature}] # :nodoc:
    UpdateCreditCardSignature = TransparentRedirectKeys + [:payment_method_token, {:credit_card => CreditCardGateway._update_signature}] # :nodoc:

    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def confirm(query_string)
      params = @gateway.transparent_redirect.parse_and_validate_query_string query_string
      confirmation_gateway = {
        TransparentRedirect::Kind::CreateCustomer => :customer,
        TransparentRedirect::Kind::UpdateCustomer => :customer,
        TransparentRedirect::Kind::CreatePaymentMethod => :credit_card,
        TransparentRedirect::Kind::UpdatePaymentMethod => :credit_card,
        TransparentRedirect::Kind::CreateTransaction => :transaction
      }[params[:kind]]

      @gateway.send(confirmation_gateway)._do_create("/transparent_redirect_requests/#{params[:id]}/confirm")
    end

    def create_credit_card_data(params)
      Util.verify_keys(CreateCreditCardSignature, params)
      params[:kind] = TransparentRedirect::Kind::CreatePaymentMethod
      _data(params)
    end

    def create_customer_data(params)
      Util.verify_keys(CreateCustomerSignature, params)
      params[:kind] = TransparentRedirect::Kind::CreateCustomer
      _data(params)
    end

    def parse_and_validate_query_string(query_string) # :nodoc:
      params = Util.symbolize_keys(Util.parse_query_string(query_string))
      query_string_without_hash = query_string.split("&").reject{|param| param =~ /\Ahash=/}.join("&")
      decoded_query_string_without_hash = Util.url_decode(query_string_without_hash)
      encoded_query_string_without_hash = Util.url_encode(query_string_without_hash)

      if params[:http_status] == nil
        raise UnexpectedError, "expected query string to have an http_status param"
      elsif params[:http_status] != '200'
        Util.raise_exception_for_status_code(params[:http_status], params[:bt_message])
      end

      query_strings_without_hash = [query_string_without_hash, encoded_query_string_without_hash, decoded_query_string_without_hash]

      if query_strings_without_hash.any? { |query_string| @config.signature_service.hash(query_string) == params[:hash] }
        params
      else
        raise ForgedQueryString
      end
    end

    def transaction_data(params)
      Util.verify_keys(TransactionSignature, params)
      params[:kind] = TransparentRedirect::Kind::CreateTransaction
      transaction_type = params[:transaction] && params[:transaction][:type]
      unless %w[sale credit].include?(transaction_type)
        raise ArgumentError, "expected transaction[type] of sale or credit, was: #{transaction_type.inspect}"
      end
      _data(params)
    end

    def update_credit_card_data(params)
      Util.verify_keys(UpdateCreditCardSignature, params)
      unless params[:payment_method_token]
        raise ArgumentError, "expected params to contain :payment_method_token of payment method to update"
      end
      params[:kind] = TransparentRedirect::Kind::UpdatePaymentMethod
      _data(params)
    end

    def update_customer_data(params)
      Util.verify_keys(UpdateCustomerSignature, params)
      unless params[:customer_id]
        raise ArgumentError, "expected params to contain :customer_id of customer to update"
      end
      params[:kind] = TransparentRedirect::Kind::UpdateCustomer
      _data(params)
    end

    def url
      "#{@config.base_merchant_url}/transparent_redirect_requests"
    end

    def _data(params) # :nodoc:
      raise ArgumentError, "expected params to contain :redirect_url" unless params[:redirect_url]

      @config.signature_service.sign(params.merge(
        :api_version => @config.api_version,
        :time => Time.now.utc.strftime("%Y%m%d%H%M%S"),
        :public_key => @config.public_key
      ))
    end
  end
end

