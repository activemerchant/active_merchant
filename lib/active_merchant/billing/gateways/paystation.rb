module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaystationGateway < Gateway

      self.live_url = self.test_url = "https://www.paystation.co.nz/direct/paystation.dll"

      # an "error code" of "0" means "No error - transaction successful"
      SUCCESSFUL_RESPONSE_CODE = '0'

      # an "error code" of "34" means "Future Payment Stored OK"
      SUCCESSFUL_FUTURE_PAYMENT = '34'

      # TODO: check this with paystation
      self.supported_countries = ['NZ']

      # TODO: check this with paystation (amex and diners need to be enabled)
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club ]

      self.homepage_url        = 'http://paystation.co.nz'
      self.display_name        = 'Paystation'

      self.default_currency    = 'NZD'
      self.money_format        = :cents

      def initialize(options = {})
        requires!(options, :paystation_id, :gateway_id)
        super
      end

      def authorize(money, credit_card, options = {})
        post = new_request

        add_invoice(post, options)
        add_amount(post, money, options)

        add_credit_card(post, credit_card)

        add_authorize_flag(post, options)

        commit(post)
      end

      def capture(money, authorization_token, options = {})
        post = new_request

        add_invoice(post, options)
        add_amount(post, money, options)

        add_authorization_token(post, authorization_token, options[:credit_card_verification])

        commit(post)
      end

      def purchase(money, payment_source, options = {})
        post = new_request

        add_invoice(post, options)
        add_amount(post, money, options)

        if payment_source.is_a?(String)
          add_token(post, payment_source)
        else
          add_credit_card(post, payment_source)
        end

        add_customer_data(post, options) if options.has_key?(:customer)

        commit(post)
      end

      def store(credit_card, options = {})
        post = new_request

        add_invoice(post, options)
        add_credit_card(post, credit_card)
        store_credit_card(post, options)

        commit(post)
      end

      private

        def new_request
          {
            :pi    => @options[:paystation_id], # paystation account id
            :gi    => @options[:gateway_id],    # paystation gateway id
            "2p"   => "t",                      # two-party transaction type
            :nr    => "t",                      # -- redirect??
            :df    => "yymm"                    # date format: optional sometimes, required others
          }
        end

        def add_customer_data(post, options)
          post[:mc] = options[:customer]
        end

        def add_invoice(post, options)
          requires!(options, :order_id)

          post[:ms] = options[:order_id]     # "Merchant Session", must be unique per request
          post[:mo] = options[:invoice]      # "Order Details", displayed in Paystation Admin
          post[:mr] = options[:description]  # "Merchant Reference Code", seen from Paystation Admin
        end

        def add_credit_card(post, credit_card)

          post[:cn] = credit_card.number
          post[:ct] = credit_card.brand
          post[:ex] = format_date(credit_card.month, credit_card.year)
          post[:cc] = credit_card.verification_value if credit_card.verification_value?

        end

        # bill a token (stored via "store") rather than a Credit Card
        def add_token(post, token)
          post[:fp] = "t"    # turn on "future payments" - what paystation calls Token Billing
          post[:ft] = token
        end

        def store_credit_card(post, options)

          post[:fp] = "t"                                # turn on "future payments" - what paystation calls Token Billing
          post[:fs] = "t"                                # tells paystation to store right now, not bill
          post[:ft] = options[:token] if options[:token] # specify a token to use that, or let Paystation generate one

        end

        def add_authorize_flag(post, options)
          post[:pa] = "t" # tells Paystation that this is a pre-auth authorisation payment (account must be in pre-auth mode)
        end

        def add_authorization_token(post, auth_token, verification_value = nil)
          post[:cp] = "t" # Capture Payment flag – tells Paystation this transaction should be treated as a capture payment
          post[:cx] = auth_token
          post[:cc] = verification_value
        end

        def add_amount(post, money, options)

          post[:am] = amount(money)
          post[:cu] = options[:currency] || currency(money)

        end

        def parse(xml_response)
          response = {}

          xml = REXML::Document.new(xml_response)

          # for normal payments, the root node is <Response>
          # for "future payments", it's <PaystationFuturePaymentResponse>
          xml.elements.each("#{xml.root.name}/*") do |element|
            response[element.name.underscore.to_sym] = element.text
          end

          response
        end

        def commit(post)

          post[:tm] = "T" if test? # test mode

          pstn_prefix_params = post.collect { |key, value| "pstn_#{key}=#{CGI.escape(value.to_s)}" }.join("&")

          # need include paystation param as "initiator flag for payment engine"
          data     = ssl_post(self.live_url, "#{pstn_prefix_params}&paystation=_empty")
          response = parse(data)
          message  = message_from(response)

          PaystationResponse.new(success?(response), message, response,
              :test          => (response[:tm] && response[:tm].downcase == "t"),
              :authorization => response[:paystation_transaction_id]
          )
        end

        def success?(response)
          (response[:ec] == SUCCESSFUL_RESPONSE_CODE) || (response[:ec] == SUCCESSFUL_FUTURE_PAYMENT)
        end

        def message_from(response)
          response[:em]
        end

        def format_date(month, year)
          "#{format(year, :two_digits)}#{format(month, :two_digits)}"
        end

    end

    class PaystationResponse < Response
      # add a method to response so we can easily get the token
      # for Validate transactions
      def token
        @params["future_payment_token"]
      end
    end
  end
end

