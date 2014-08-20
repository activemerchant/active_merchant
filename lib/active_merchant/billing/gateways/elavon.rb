require File.dirname(__FILE__) + '/viaklix'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # = Elavon Virtual Merchant Gateway
    #
    # == Example use:
    #
    #   gateway = ActiveMerchant::Billing::ElavonGateway.new(
    #               :login     => "my_virtual_merchant_id",
    #               :password  => "my_virtual_merchant_pin",
    #               :user      => "my_virtual_merchant_user_id" # optional
    #            )
    #
    #   # set up credit card obj as in main ActiveMerchant example
    #   creditcard = ActiveMerchant::Billing::CreditCard.new(
    #     :type       => 'visa',
    #     :number     => '41111111111111111',
    #     :month      => 10,
    #     :year       => 2011,
    #     :first_name => 'Bob',
    #     :last_name  => 'Bobsen'
    #   )
    #
    #   # run request
    #   response = gateway.purchase(1000, creditcard) # authorize and capture 10 USD
    #
    #   puts response.success?      # Check whether the transaction was successful
    #   puts response.message       # Retrieve the message returned by Elavon
    #   puts response.authorization # Retrieve the unique transaction ID returned by Elavon
    #
    class ElavonGateway < Gateway
      class_attribute :test_url, :live_url, :delimiter, :actions

      self.test_url = 'https://demo.myvirtualmerchant.com/VirtualMerchantDemo/process.do'
      self.live_url = 'https://www.myvirtualmerchant.com/VirtualMerchant/process.do'

      self.display_name = 'Elavon MyVirtualMerchant'
      self.supported_countries = %w(US CA PR DE IE NO PL LU BE NL)
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.elavon.com/'

      self.delimiter = "\n"
      self.actions = {
        :purchase => 'CCSALE',
        :credit => 'CCCREDIT',
        :refund => 'CCRETURN',
        :authorize => 'CCAUTHONLY',
        :capture => 'CCFORCE',
        :void => 'CCDELETE',
        :store => 'CCGETTOKEN',
        :update => 'CCUPDATETOKEN',
      }

      # Initialize the Gateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- Merchant ID
      # * <tt>:password</tt> -- PIN
      # * <tt>:user</tt> -- Specify a subuser of the account (optional)
      # * <tt>:test => +true+ or +false+</tt> -- Force test transactions
      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      # Make a purchase
      def purchase(money, payment_method, options = {})
        form = {}
        add_salestax(form, options)
        add_invoice(form, options)
        if payment_method.is_a?(String)
          add_token(form, payment_method)
        else
          add_creditcard(form, payment_method)
        end
        add_address(form, options)
        add_customer_data(form, options)
        add_test_mode(form, options)
        commit(:purchase, money, form)
      end

      # Authorize a credit card for a given amount.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be authorized as an Integer value in cents.
      # * <tt>credit_card</tt> - The CreditCard details for the transaction.
      # * <tt>options</tt>
      #   * <tt>:billing_address</tt> - The billing address for the cardholder.
      def authorize(money, creditcard, options = {})
        form = {}
        add_salestax(form, options)
        add_invoice(form, options)
        add_creditcard(form, creditcard)
        add_address(form, options)
        add_customer_data(form, options)
        add_test_mode(form, options)
        commit(:authorize, money, form)
      end

      # Capture authorized funds from a credit card.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be captured as an Integer value in cents.
      # * <tt>authorization</tt> - The approval code returned from the initial authorization.
      # * <tt>options</tt>
      #   * <tt>:credit_card</tt> - The CreditCard details from the initial transaction (required).
      def capture(money, authorization, options = {})
        requires!(options, :credit_card)

        form = {}
        add_salestax(form, options)
        add_approval_code(form, authorization)
        add_invoice(form, options)
        add_creditcard(form, options[:credit_card])
        add_customer_data(form, options)
        add_test_mode(form, options)
        commit(:capture, money, form)
      end

      # Refund a transaction.
      #
      # This transaction indicates to the gateway that
      # money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be credited to the customer as an Integer value in cents.
      # * <tt>identification</tt> -- The ID of the original transaction against which the refund is being issued.
      # * <tt>options</tt> -- A hash of parameters.
      def refund(money, identification, options = {})
        form = {}
        add_txn_id(form, identification)
        add_test_mode(form, options)
        commit(:refund, money, form)
      end

      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization returned from the previous request.
      def void(identification, options = {})
        form = {}
        add_txn_id(form, identification)
        add_test_mode(form, options)
        commit(:void, nil, form)
      end

      # Make a credit to a card.  Use the refund method if you'd like to credit using
      # previous transaction
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be credited as an Integer value in cents.
      # * <tt>creditcard</tt> - The credit card to be credited.
      # * <tt>options</tt>
      def credit(money, creditcard, options = {})
        if creditcard.is_a?(String)
          raise ArgumentError, "Reference credits are not supported. Please supply the original credit card or use the #refund method."
        end

        form = {}
        add_invoice(form, options)
        add_creditcard(form, creditcard)
        add_address(form, options)
        add_customer_data(form, options)
        add_test_mode(form, options)
        commit(:credit, money, form)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(creditcard, options = {})
        form = {}
        add_creditcard(form, creditcard)
        add_address(form, options)
        add_customer_data(form, options)
        add_test_mode(form, options)
        add_verification(form, options)
        form[:add_token] = 'Y'
        commit(:store, nil, form)
      end

      def update(token, creditcard, options = {})
        form = {}
        add_token(form, token)
        add_creditcard(form, creditcard)
        add_address(form, options)
        add_customer_data(form, options)
        add_test_mode(form, options)
        commit(:update, nil, form)
      end

      private

      def add_invoice(form,options)
        form[:invoice_number] = (options[:order_id] || options[:invoice]).to_s.slice(0, 10)
        form[:description] = options[:description].to_s.slice(0, 255)
      end

      def add_approval_code(form, authorization)
        form[:approval_code] = authorization.split(';').first
      end

      def add_txn_id(form, authorization)
        form[:txn_id] = authorization.split(';').last
      end

      def authorization_from(response)
        [response['approval_code'], response['txn_id']].join(';')
      end

      def add_creditcard(form, creditcard)
        form[:card_number] = creditcard.number
        form[:exp_date] = expdate(creditcard)

        if creditcard.verification_value?
          add_verification_value(form, creditcard)
        end

        form[:first_name] = creditcard.first_name.to_s.slice(0, 20)
        form[:last_name] = creditcard.last_name.to_s.slice(0, 30)
      end

      def add_token(form, token)
        form[:token] = token
      end

      def add_verification_value(form, creditcard)
        form[:cvv2cvc2] = creditcard.verification_value
        form[:cvv2cvc2_indicator] = '1'
      end

      def add_customer_data(form, options)
        form[:email] = options[:email].to_s.slice(0, 100) unless options[:email].blank?
        form[:customer_code] = options[:customer].to_s.slice(0, 10) unless options[:customer].blank?
      end

      def add_salestax(form, options)
        form[:salestax] = options[:tax] if options[:tax].present?
      end

      def add_address(form,options)
        billing_address = options[:billing_address] || options[:address]

        if billing_address
          form[:avs_address]    = billing_address[:address1].to_s.slice(0, 30)
          form[:address2]       = billing_address[:address2].to_s.slice(0, 30)
          form[:avs_zip]        = billing_address[:zip].to_s.slice(0, 10)
          form[:city]           = billing_address[:city].to_s.slice(0, 30)
          form[:state]          = billing_address[:state].to_s.slice(0, 10)
          form[:company]        = billing_address[:company].to_s.slice(0, 50)
          form[:phone]          = billing_address[:phone].to_s.slice(0, 20)
          form[:country]        = billing_address[:country].to_s.slice(0, 50)
        end

        if shipping_address = options[:shipping_address]
          first_name, last_name = parse_first_and_last_name(shipping_address[:name])
          form[:ship_to_first_name]     = first_name.to_s.slice(0, 20)
          form[:ship_to_last_name]      = last_name.to_s.slice(0, 30)
          form[:ship_to_address1]       = shipping_address[:address1].to_s.slice(0, 30)
          form[:ship_to_address2]       = shipping_address[:address2].to_s.slice(0, 30)
          form[:ship_to_city]           = shipping_address[:city].to_s.slice(0, 30)
          form[:ship_to_state]          = shipping_address[:state].to_s.slice(0, 10)
          form[:ship_to_company]        = shipping_address[:company].to_s.slice(0, 50)
          form[:ship_to_country]        = shipping_address[:country].to_s.slice(0, 50)
          form[:ship_to_zip]            = shipping_address[:zip].to_s.slice(0, 10)
        end
      end

      def add_verification(form, options)
        form[:verify] = 'Y' if options[:verify]
      end

      def parse_first_and_last_name(value)
        name = value.to_s.split(' ')

        last_name = name.pop || ''
        first_name = name.join(' ')
        [ first_name, last_name ]
      end

      def add_test_mode(form, options)
        form[:test_mode] = 'TRUE' if options[:test_mode]
      end

      def message_from(response)
        success?(response) ? response['result_message'] : response['errorMessage']
      end

      def success?(response)
        !response.has_key?('errorMessage')
      end

      def commit(action, money, parameters)
        parameters[:amount] = amount(money)
        parameters[:transaction_type] = self.actions[action]

        response = parse( ssl_post(test? ? self.test_url : self.live_url, post_data(parameters)) )

        Response.new(response['result'] == '0', message_from(response), response,
          :test => @options[:test] || test?,
          :authorization => authorization_from(response),
          :avs_result => { :code => response['avs_response'] },
          :cvv_result => response['cvv2_response']
        )
      end

      def post_data(parameters)
        result = preamble
        result.merge!(parameters)
        result.collect { |key, value| "ssl_#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def preamble
        result = {
          'merchant_id'   => @options[:login],
          'pin'           => @options[:password],
          'show_form'     => 'false',
          'result_format' => 'ASCII'
        }

        result['user_id'] = @options[:user] unless @options[:user].blank?
        result
      end

      def parse(msg)
        resp = {}
        msg.split(self.delimiter).collect{|li|
            key, value = li.split("=")
            resp[key.to_s.strip.gsub(/^ssl_/, '')] = value.to_s.strip
          }
        resp
      end

    end
  end
end

