module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CertoDirectGateway < Gateway
      self.live_url = self.test_url = "https://secure.certodirect.com/gateway/process/v2"

      self.supported_countries = [
        "BE", "BG", "CZ", "DK", "DE", "EE", "IE", "ES", "FR",
        "IT", "CY", "LV", "LT", "LU", "HU", "MT", "NL", "AT", "PL",
        "PT", "RO", "SI", "SK", "FI", "SE", "GB"
      ]

      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.certodirect.com/'
      self.display_name = 'CertoDirect'

      # Creates a new CertoDirectGateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The CertoDirect Shop ID (REQUIRED)
      # * <tt>:password</tt> -- The CertoDirect Shop Password. (REQUIRED)
      # * <tt>:test</tt> -- +true+ or +false+. If true, perform transactions against the test server.
      #   Otherwise, perform transactions against the production server.
      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>credit_card</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def purchase(money, credit_card, options = {})
        requires!(options, :email, :currency, :ip, :description)

        commit(build_sale_request(money, credit_card, options))
      end

      # Refund a transaction.
      #
      # This transaction indicates to the gateway that
      # money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be credited to the customer as an Integer value in cents.
      # * <tt>identification</tt> -- The ID of the original order against which the refund is being issued.
      # * <tt>options</tt> -- A hash of parameters.
      def refund(money, identification, options = {})
        requires!(options, :reason)

        commit(build_refund_request(money, identification, options))
      end

      # Performs an authorization, which reserves the funds on the customer's credit card, but does not
      # charge the card.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
      # * <tt>credit_card</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def authorize(money, credit_card, options = {})
        requires!(options, :email, :currency, :ip, :description)

        commit(build_authorize_request(money, credit_card, options))
      end

      # Captures the funds from an authorized transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as an Integer value in cents.
      # * <tt>identification</tt> -- The authorization returned from the previous authorize request.
      def capture(money, identification, options = {})
        commit(build_capture_request(money, identification))
      end

      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as an Integer value in cents.
      # * <tt>identification</tt> - The authorization returned from the previous authorize request.
      def void(money, identification, options = {})
        commit(build_void_request(money, identification))
      end

      # Create a recurring payment.
      #
      # ==== Parameters
      #
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      def recurring(identification, options={})
        deprecated RECURRING_DEPRECATION_MESSAGE

        commit(build_recurring_request(identification, options))
      end

      private

      def commit(request_xml)
        begin
          response = Hash.from_xml(ssl_post(self.live_url, request_xml, headers))
          Response.new(success?(response),
                       message(response),
                       response,
                       :test          => test?,
                       :authorization => authorization(response))
        rescue ResponseError => e
          raise e unless e.response.code == '403'
          response = Hash.from_xml(e.response.body)['response']
          Response.new(false, message(response), {}, :test => test?)
        end
      end

      def build_sale_request(money, credit_card, options)
        build_request_xml('Sale') do |xml|
          add_order(xml, money, credit_card, options)
        end
      end

      def build_authorize_request(money, credit_card, options)
        build_request_xml('Authorize') do |xml|
          add_order(xml, money, credit_card, options)
        end
      end

      def build_refund_request(money, identification, options)
        build_request_xml('Refund') do |xml|
          add_reference_info(xml, money, identification, options)
          xml.tag! 'reason', options[:reason]
        end
      end

      def build_capture_request(money, identification)
        build_request_xml('Capture') do |xml|
          add_reference_info(xml, money, identification, options)
        end
      end

      def build_void_request(money, identification)
        build_request_xml('Void') do |xml|
          add_reference_info(xml, money, identification, options)
        end
      end

      def build_recurring_request(identification, options)
        build_request_xml('Sale') do |xml|
          xml.tag! 'order' do |xml|
            xml.tag!('test', 'true') if test?
            xml.tag! 'initial_order_id', identification, :type => 'integer'

            add_order_details(xml, options[:amount], options) if has_any_order_details_key?(options)
            add_address(xml, 'billing_address', options[:billing_address]) if options[:billing_address]
            add_address(xml, 'shipping_address', options[:shipping_address]) if options[:shipping_address]
          end
        end
      end

      def build_request_xml(type, &block)
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.tag! 'transaction' do
          xml.tag! 'type', type
          yield(xml)
        end
        xml.target!
      end

      def add_order(xml, money, credit_card, options)
        xml.tag! 'order' do
          xml.tag!('test', 'true') if test?

          xml.tag!('return_url', options[:return_url]) if options[:return_url]
          xml.tag!('cancel_url', options[:cancel_url]) if options[:cancel_url]

          xml.tag! 'payment_method_type', 'CreditCard'
          xml.tag! 'payment_method' do
            xml.tag! 'number', credit_card.number
            xml.tag! 'exp_month', "%02i" % credit_card.month
            xml.tag! 'exp_year', credit_card.year
            xml.tag! 'holder', credit_card.name
            xml.tag! 'verification_value', credit_card.verification_value
          end

          add_order_details(xml, money, options)
          add_address(xml, 'billing_address', options[:billing_address]) if options[:billing_address]
          add_address(xml, 'shipping_address', options[:shipping_address]) if options[:shipping_address]
        end
      end

      def add_order_details(xml, money, options)
        xml.tag! 'details' do
          xml.tag!('amount', localized_amount(money, options[:currency]), :type => 'decimal') if money
          xml.tag!('currency', options[:currency]) if options[:currency]
          xml.tag!('email', options[:email]) if options[:email]
          xml.tag!('ip', options[:ip]) if options[:ip]
          xml.tag!('shipping', options[:shipping], :type => 'decimal') if options[:shipping]
          xml.tag!('description', options[:description]) if options[:description]
        end
      end

      def add_reference_info(xml, money, identification, options)
        xml.tag! 'order_id', identification, :type => 'integer'
        xml.tag! 'amount', localized_amount(money, options[:currency]), :type => 'decimal'
      end

      def add_address(xml, address_type, address)
        xml.tag! address_type do
          xml.tag! 'address', address[:address1]
          xml.tag! 'city', address[:city]
          xml.tag! 'country', address[:country]
          xml.tag! 'first_name', address[:first_name]
          xml.tag! 'last_name', address[:last_name]
          xml.tag! 'state', address[:state]
          xml.tag! 'phone', address[:phone]
          xml.tag! 'zip', address[:zip]
        end
      end

      def has_any_order_details_key?(options)
        [ :currency, :amount, :email, :ip, :shipping, :description ].any? do |key|
          options.has_key?(key)
        end
      end

      def success?(response)
        %w(completed forwarding).include?(state(response)) and
          status(response) == 'success'
      end

      def error?(response)
        response['errors']
      end

      def state(response)
        response["transaction"].try(:[], "state")
      end

      def status(response)
        response['transaction'].try(:[], 'response').try(:[], 'status')
      end

      def authorization(response)
        error?(response) ? nil : response["transaction"]["order"]['id'].to_s
      end

      def message(response)
        return response['errors'].join('; ') if error?(response)

        if state(response) == 'completed'
          response["transaction"]["response"]["message"]
        else
          response['transaction']['message']
        end
      end

      def headers
        { 'authorization' => basic_auth,
          'Accept'        => 'application/xml',
          'Content-Type'  => 'application/xml' }
      end

      def basic_auth
        'Basic ' + ["#{@options[:login]}:#{@options[:password]}"].pack('m').delete("\r\n")
      end
    end
  end
end
