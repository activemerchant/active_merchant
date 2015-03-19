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

      # Authorization - the second parameter may be a CreditCard or
      # a String which represents a GuWID reference to an earlier
      # transaction.  If a GuWID is given, rather than a CreditCard,
      # then then the :recurring option will be forced to "Repeated"
      def authorize(money, payment_method, options = {})
        if payment_method.respond_to?(:number)
          options[:credit_card] = payment_method
        else
          options[:preauthorization] = payment_method
        end
        commit(:preauthorization, money, options)
      end

      def capture(money, authorization, options = {})
        options[:preauthorization] = authorization
        commit(:capture, money, options)
      end

      # Purchase - the second parameter may be a CreditCard or
      # a String which represents a GuWID reference to an earlier
      # transaction.  If a GuWID is given, rather than a CreditCard,
      # then then the :recurring option will be forced to "Repeated"
      def purchase(money, payment_method, options = {})
        if payment_method.respond_to?(:number)
          options[:credit_card] = payment_method
        else
          options[:preauthorization] = payment_method
        end
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

      # Store card - Wirecard supports the notion of "Recurring
      # Transactions" by allowing the merchant to provide a reference
      # to an earlier transaction (the GuWID) rather than a credit
      # card.  A reusable reference (GuWID) can be obtained by sending
      # a purchase or authorization transaction with the element
      # "RECURRING_TRANSACTION/Type" set to "Initial".  Subsequent
      # transactions can then use the GuWID in place of a credit
      # card by setting "RECURRING_TRANSACTION/Type" to "Repeated".
      #
      # This implementation of card store utilizes a Wirecard
      # "Authorization Check" (a Preauthorization that is automatically
      # reversed).  It defaults to a check amount of "100" (i.e.
      # $1.00) but this can be overriden (see below).
      #
      # IMPORTANT: In order to reuse the stored reference, the
      # +authorization+ from the response should be saved by
      # your application code.
      #
      # ==== Options specific to +store+
      #
      # * <tt>:amount</tt> -- The amount, in cents, that should be
      #   "validated" by the Authorization Check.  This amount will
      #   be reserved and then reversed.  Default is 100.
      #
      # Note: This is not the only way to achieve a card store
      # operation at Wirecard.  Any +purchase+ or +authorize+
      # can be sent with +options[:recurring] = 'Initial'+ to make
      # the returned authorization/GuWID usable in later transactions
      # with +options[:recurring] = 'Repeated'+.
      def store(creditcard, options = {})
        options[:credit_card] = creditcard
        options[:recurring] = 'Initial'
        money = options.delete(:amount) || 100
        # Amex does not support authorization_check
        if creditcard.brand == 'american_express'
          commit(:preauthorization, money, options)
        else
          commit(:authorization_check, money, options)
        end
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

      # If a GuWID (string-based reference) is passed rather than a
      # credit card, then the :recurring type needs to be forced to
      # "Repeated"
      def setup_recurring_flag(options)
        options[:recurring] = 'Repeated' if options[:preauthorization].present?
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
          :avs_result => { :code => avs_code(response, options) },
          :cvv_result => response[:CVCResponseCode]
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
            xml.tag! 'CommerceType', options[:commerce_type] if options[:commerce_type]
            case options[:action]
            when :preauthorization, :purchase, :authorization_check
              setup_recurring_flag(options)
              add_invoice(xml, money, options)

              if options[:credit_card]
                add_creditcard(xml, options[:credit_card])
              else
                xml.tag! 'GuWID', options[:preauthorization]
              end

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
          parse_error_only_response(response, root)
        else
          response[:Message] = "No valid XML response message received. \
                                Propably wrong credentials supplied with HTTP header."
        end

        response
      end

      def parse_error_only_response(response, root)
        error_code = REXML::XPath.first(root, "Number")
        response[:ErrorCode] = error_code.text if error_code
        response[:Message] = parse_error(root)
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
            if (node.elements.size == 0)
              response[node.name.to_sym] = (node.text || '').strip
            else
              node.elements.each do |childnode|
                name = "#{node.name}_#{childnode.name}"
                response[name.to_sym] = (childnode.text || '').strip
              end
            end
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
          string << error[:Message] if error[:Message]
          error[:Advice].each_with_index do |advice, index|
            string << ' (' if index == 0
            string << "#{index+1}. #{advice}"
            string << ' and ' if index < error[:Advice].size - 1
            string << ')' if index == error[:Advice].size - 1
          end
        end
        string
      end

      # Amex have different AVS response codes
      AMEX_TRANSLATED_AVS_CODES = {
        "A" => "B", # CSC and Address Matched
        "F" => "D", # All Data Matched
        "N" => "I", # CSC Match
        "U" => "U", # Data Not Checked
        "Y" => "D", # All Data Matched
        "Z" => "P", # CSC and Postcode Matched
      }

      # Amex have different AVS response codes to visa etc
      def avs_code(response, options)
        if response.has_key?(:AVS_ProviderResultCode)
          if options[:credit_card].present? && ActiveMerchant::Billing::CreditCard.brand?(options[:credit_card].number) == "american_express"
            AMEX_TRANSLATED_AVS_CODES[response[:AVS_ProviderResultCode]]
          else
            response[:AVS_ProviderResultCode]
          end
        end
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

