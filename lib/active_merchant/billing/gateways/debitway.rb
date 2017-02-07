module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # This class implements the {Debitway}[http://www.debitway.com] payment gateway.
    #
    # == Supported transaction types by Beanstream:
    # * - sale
    # * - authonly
    # * - capture
    # * - refund
    #
    # * Ensure that country and province data is provided in ISO-CODE such as: "CA", "US", "QC"
    #
    #  Example authorization (DebitWay Sale transaction type):
    #
    #   twenty = 20.00
    #   gateway = DebitwayGateway.new(
    #     :identifier => 'm88267df33242',
    #     :vericode => 'password',
    #     :website_unique_id => 'xiaobozz'
    #   )
    #
    #   credit_card = CreditCard.new(
    #     :number => '4030000010001234',
    #     :month => 8,
    #     :year => 2011,
    #     :first_name => 'xiaobo',
    #     :last_name => 'zzz',
    #     :verification_value => 137
    #   )

    class DebitwayGateway < Gateway
      self.test_url = 'https://www.debitway.com/integration/index.php'
      self.live_url = 'https://www.debitway.com/integration/index.php'

      self.supported_countries = ['US','CA']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.debitway.com/'
      self.display_name = 'DebitWay'

      TRANSACTION = {
        :authorization              => 'transaction_id',
        :result                     => 'result',
        :errors                     => 'errors',
        :customer_errors_meaning    => 'customer_errors_meaning'
      }

      def initialize(options={})
        requires!(options, :identifier, :vericode, :website_unique_id)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)
        add_credit_card(post, payment)
        add_customer_ip(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)
        add_credit_card(post, payment)
        add_customer_ip(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        post = {}
        add_txn_authorization(post, authorization)
        add_amount(post, money)
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        post = {}
        post[:comments] = "Transaction Refund Request";
        add_txn_authorization(post, authorization)
        add_amount(post, money)
        commit('refund', post)
      end

      def void(authorization, options={})
        post = {}
        post[:comments] = "Authorized Transaction Decline Request";
        add_txn_authorization(post, authorization)
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
            .gsub( /(&?cc_number=)[^&\s]*(&?)/, '\1[FILTERED]\2')
            .gsub( /(&?cc_expdate=)[^&\s]*(&?)/, '\1[FILTERED]\2')
            .gsub( /(&?cc_security_code=)[^&\s]*(&?)/, '\1[FILTERED]\2')
            .gsub( /(&?identifier=)[^&\s]*(&?)/, '\1[FILTERED]\2')
            .gsub( /(&?vericode=)[^&\s]*(&?)/, '\1[FILTERED]\2')
            .gsub( /(&?website_unique_id=)[^&\s]*(&?)/, '\1[FILTERED]\2')
      end

      private

      def add_txn_authorization(post, authorization)
        post[:transaction_id]  =  authorization;
      end


      def add_customer_data(post, options)
        post[:first_name]   = options[:first_name]
        post[:last_name]    = options[:last_name]
        post[:email]        = options[:email]
        post[:phone]        = options[:phone]
      end


      def add_credit_card(post, credit_card)
        if credit_card
            post[:cc_type]          = credit_card.brand.upcase
            post[:cc_number]        = credit_card.number
            post[:cc_expdate]       = "#{ credit_card.year.to_s[-2,2] }#{ '%02d' %credit_card.month }"
            post[:cc_security_code] = credit_card.verification_value
        end
      end


      def add_customer_ip(post, options)
        post[:ip_address] = options[:ip] if options[:ip]
        post[:return_url] = options[:return_url]
      end


      def add_address(post, creditcard, options)
        if billing_address = options[:billing_address] || options[:address]
            post[:address]              = "#{billing_address[:address1]} #{billing_address[:address2]}"
            post[:city]                 = billing_address[:city]
            post[:state_or_province]    = billing_address[:state]
            post[:zip_or_postal_code]   = billing_address[:zip]
            post[:country]              = billing_address[:country]
        end
        if shipping_address = options[:shipping_address]
            post[:shipping_address]              = "#{shipping_address[:address1]} #{shipping_address[:address2]}"
            post[:shipping_city]                 = shipping_address[:city]
            post[:shipping_state_or_province]    = shipping_address[:state]
            post[:shipping_zip_or_postal_code]   = shipping_address[:zip]
            post[:shipping_country]              = shipping_address[:country]
        end
      end


      def add_invoice(post, money, options)
        post[:merchant_transaction_id]  = options[:order_id]
        post[:item_name]                = options[:description]
        post[:custom]                   = options[:custom]
        post[:amount]                   = amount(money)
        post[:currency]                 = (options[:currency] || currency(money))
        post[:quantity]                 = 1
      end

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def add_payment(post, payment)
      end

      def parse(body)
        response = body.scan(/([\w]+)="(.*?)\"/)

        formatted = {}
        response.each do | variable |
            formatted[variable[0]] = variable[1]
        end

        formatted
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        post_vars = post_data(action, parameters)

        response = parse(ssl_post(url, post_vars.to_query))

        Response.new(
          success_from?(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response[TRANSACTION[:errors]]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from?(response)
        response[TRANSACTION[:result]] == 'success'
      end

      def message_from(response)
        if response[TRANSACTION[:result]] == 'failed'
           ## "Processor declined: #{ response[ TRANSACTION[:customer_errors_meaning] ] }"
           "FAILURE"
        else
          "SUCCESS"
        end
      end

      def authorization_from(response)
        "#{response[TRANSACTION[:authorization]]}"
      end

      def post_data(action = '', params = {})
        params[:identifier]         = @options[:identifier] ? @options[:identifier] : 'not-valid'
        params[:website_unique_id]  = @options[:website_unique_id]
        params[:vericode]           = @options[:vericode]

        case action
            when "sale"
                params[:action] = 'payment';

            when "authonly"
                params[:action] = 'authorized payment';

            when "capture", "refund"
                params[:action] = action;

            when "void"
                params[:action] = 'decline authorized payment';
        end

        params
      end

      def error_code_from(response)
        unless success_from?(response)
          response[TRANSACTION[:errors]]
        end
      end
    end
  end
end
