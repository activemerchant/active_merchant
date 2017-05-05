require 'base64'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WirecardGateway < Gateway
      self.test_url = 'https://c3-test.wirecard.com/secure/ssl-gateway'
      self.live_url = 'https://c3.wirecard.com/secure/ssl-gateway'

      # The Namespaces are not really needed, because it just tells the System, that there's actually no namespace used.
      # It's just specified here for completeness.
      ENVELOPE_NAMESPACES = {
        'xmlns:xsi' => 'http://www.w3.org/1999/XMLSchema-instance',
        'xsi:noNamespaceSchemaLocation' => 'wirecard.xsd'
      }

      PERMITTED_TRANSACTIONS = %w[ PREAUTHORIZATION CAPTURE PURCHASE ]

      RETURN_CODES = %w[ ACK NOK ]

      # Wirecard only allows phone numbers with a format like this: +xxx(yyy)zzz-zzzz-ppp, where:
      #   xxx = Country code
      #   yyy = Area or city code
      #   zzz-zzzz = Local number
      #   ppp = PBX extension
      # For example, a typical U.S. or Canadian number would be "+1(202)555-1234-739" indicating PBX extension 739 at phone
      # number 5551234 within area code 202 (country code 1).
      VALID_PHONE_FORMAT = /\+\d{1,3}(\(?\d{3}\)?)?\d{3}-\d{4}-\d{3}/

      self.supported_cardtypes = [ :visa, :master, :american_express, :diners_club, :jcb, :switch ]
      self.supported_countries = %w(AD CY GI IM MT RO CH AT DK GR IT MC SM TR BE EE HU LV NL SK GB BG FI IS LI NO SI VA FR IL LT PL ES CZ DE IE LU PT SE)
      self.homepage_url = 'http://www.wirecard.com'
      self.display_name = 'Wirecard'
      self.default_currency = 'EUR'
      self.money_format = :cents

      # Public: Create a new Wirecard gateway.
      #
      # options - A hash of options:
      #           :login         - The username
      #           :password      - The password
      #           :signature     - The BusinessCaseSignature
      def initialize(options = {})
        requires!(options, :login, :password, :signature)
        super
      end

      def authorize(money, creditcard, options = {})
        options[:credit_card] = creditcard
        commit(:preauthorization, money, options)
      end

      def capture(money, authorization, options = {})
        options[:preauthorization] = authorization
        commit(:capture, money, options)
      end

      def purchase(money, creditcard, options = {})
        options[:credit_card] = creditcard
        commit(:purchase, money, options)
      end

      def void(identification, options = {})
        options[:preauthorization] = identification
        commit(:reversal, nil, options)
      end

      def refund(money, identification, options = {})
        options[:preauthorization] = identification
        commit(:bookback, money, options)
      end


      private
      def clean_description(description)
        description.to_s.slice(0,32).encode("US-ASCII", invalid: :replace, undef: :replace, replace: '?')
      end

      def prepare_options_hash(options)
        result = @options.merge(options)
        setup_address_hash!(result)
        result
      end

      # Create all address hash key value pairs so that
      # it still works if only provided with one or two of them
      def setup_address_hash!(options)
        options[:billing_address] = options[:billing_address] || options[:address] || {}
        options[:shipping_address] = options[:shipping_address] || {}
        # Include Email in address-hash from options-hash
        options[:billing_address][:email] = options[:email] if options[:email]
      end

      # Contact WireCard, make the XML request, and parse the
      # reply into a Response object
      def commit(action, money, options)
        request = build_request(action, money, options)

        headers = { 'Content-Type' => 'text/xml',
                    'Authorization' => encoded_credentials }

        response = parse(ssl_post(test? ? self.test_url : self.live_url, request, headers))
        # Pending Status also means Acknowledged (as stated in their specification)
        success = response[:FunctionResult] == "ACK" || response[:FunctionResult] == "PENDING"
        message = response[:Message]
        authorization = response[:GuWID]

        Response.new(success, message, response,
          :test => test?,
          :authorization => authorization,
          :avs_result => { :code => response[:avsCode] },
          :cvv_result => response[:cvCode]
        )
      rescue ResponseError => e
        if e.response.code == "401"
          return Response.new(false, "Invalid Login")
        else
          raise
        end
      end

      # Generates the complete xml-message, that gets sent to the gateway
      def build_request(action, money, options)
        options = prepare_options_hash(options)
        options[:action] = action
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! 'WIRECARD_BXML' do
          xml.tag! 'W_REQUEST' do
          xml.tag! 'W_JOB' do
              xml.tag! 'JobID', ''
              # UserID for this transaction
              xml.tag! 'BusinessCaseSignature', options[:signature] || options[:login]
              # Create the whole rest of the message
              add_transaction_data(xml, money, options)
            end
          end
        end
        xml.target!
      end

      # Includes the whole transaction data (payment, creditcard, address)
      def add_transaction_data(xml, money, options)
        options[:order_id] ||= generate_unique_id

        xml.tag! "FNC_CC_#{options[:action].to_s.upcase}" do
          xml.tag! 'FunctionID', clean_description(options[:description])
          xml.tag! 'CC_TRANSACTION' do
            xml.tag! 'TransactionID', options[:order_id]
            case options[:action]
            when :preauthorization, :purchase
              add_invoice(xml, money, options)
              add_creditcard(xml, options[:credit_card])
              add_address(xml, options[:billing_address])
            when :capture, :bookback
              xml.tag! 'GuWID', options[:preauthorization]
              add_amount(xml, money)
            when :reversal
              xml.tag! 'GuWID', options[:preauthorization]
            end
          end
        end
      end

      # Includes the payment (amount, currency, country) to the transaction-xml
      def add_invoice(xml, money, options)
        add_amount(xml, money)
        xml.tag! 'Currency', options[:currency] || currency(money)
        xml.tag! 'CountryCode', options[:billing_address][:country]
        xml.tag! 'RECURRING_TRANSACTION' do
          xml.tag! 'Type', options[:recurring] || 'Single'
        end
      end

      # Include the amount in the transaction-xml
      def add_amount(xml, money)
        xml.tag! 'Amount', amount(money)
      end

      # Includes the credit-card data to the transaction-xml
      def add_creditcard(xml, creditcard)
        raise "Creditcard must be supplied!" if creditcard.nil?
        xml.tag! 'CREDIT_CARD_DATA' do
          xml.tag! 'CreditCardNumber', creditcard.number
          xml.tag! 'CVC2', creditcard.verification_value
          xml.tag! 'ExpirationYear', creditcard.year
          xml.tag! 'ExpirationMonth', format(creditcard.month, :two_digits)
          xml.tag! 'CardHolderName', [creditcard.first_name, creditcard.last_name].join(' ')
        end
      end

      # Includes the IP address of the customer to the transaction-xml
      def add_customer_data(xml, options)
        return unless options[:ip]
        xml.tag! 'CONTACT_DATA' do
          xml.tag! 'IPAddress', options[:ip]
        end
      end

      # Includes the address to the transaction-xml
      def add_address(xml, address)
        return if address.nil?
        xml.tag! 'CORPTRUSTCENTER_DATA' do
          xml.tag! 'ADDRESS' do
            xml.tag! 'Address1', address[:address1]
            xml.tag! 'Address2', address[:address2] if address[:address2]
            xml.tag! 'City', address[:city]
            xml.tag! 'ZipCode', address[:zip]

            if address[:state] =~ /[A-Za-z]{2}/ && address[:country] =~ /^(us|ca)$/i
              xml.tag! 'State', address[:state].upcase
            end

            xml.tag! 'Country', address[:country]
            xml.tag! 'Phone', address[:phone] if address[:phone] =~ VALID_PHONE_FORMAT
            xml.tag! 'Email', address[:email]
          end
        end
      end

      # Read the XML message from the gateway and check if it was successful,
      # and also extract required return values from the response.
      def parse(xml)
        basepath = '/WIRECARD_BXML/W_RESPONSE'
        response = {}

        xml = REXML::Document.new(xml)
        if root = REXML::XPath.first(xml, "#{basepath}/W_JOB")
          parse_response(response, root)
        elsif root = REXML::XPath.first(xml, "//ERROR")
          parse_error(response, root)
        else
          response[:Message] = "No valid XML response message received. \
                                Propably wrong credentials supplied with HTTP header."
        end

        response
      end

      # Parse the <ProcessingStatus> Element which contains all important information
      def parse_response(response, root)
        status = nil

        root.elements.to_a.each do |node|
          if node.name =~ /FNC_CC_/
            status = REXML::XPath.first(node, "CC_TRANSACTION/PROCESSING_STATUS")
          end
        end

        message = ""
        if status
          if info = status.elements['Info']
            message << info.text
          end

          status.elements.to_a.each do |node|
            response[node.name.to_sym] = (node.text || '').strip
          end

          error_code = REXML::XPath.first(status, "ERROR/Number")
          response['ErrorCode'] = error_code.text if error_code
        end

        parse_error(root, message)
        response[:Message] = message
      end

      # Parse a generic error response from the gateway
      def parse_error(root, message = "")
        # Get errors if available and append them to the message
        errors = errors_to_string(root)
        unless errors.strip.blank?
          message << ' - ' unless message.strip.blank?
          message << errors
        end
        message
      end

      # Parses all <ERROR> elements in the response and converts the information
      # to a single string
      def errors_to_string(root)
        # Get context error messages (can be 0..*)
        errors = []
        REXML::XPath.each(root, "//ERROR") do |error_elem|
          error = {}
          error[:Advice] = []
          error[:Message] = error_elem.elements['Message'].text
          error_elem.elements.each('Advice') do |advice|
            error[:Advice] << advice.text
          end
          errors << error
        end
        # Convert all messages to a single string
        string = ''
        errors.each do |error|
          string << error[:Message]
          error[:Advice].each_with_index do |advice, index|
            string << ' (' if index == 0
            string << "#{index+1}. #{advice}"
            string << ' and ' if index < error[:Advice].size - 1
            string << ')' if index == error[:Advice].size - 1
          end
        end
        string
      end

      # Encode login and password in Base64 to supply as HTTP header
      # (for http basic authentication)
      def encoded_credentials
        credentials = [@options[:login], @options[:password]].join(':')
        "Basic " << Base64.encode64(credentials).strip
      end
    end
  end
end

