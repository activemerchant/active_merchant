module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # ActiveMerchant Implementation for Quantum Gateway XML Requester Service
    # Based on API Doc from 8/6/2009
    #
    # Important Notes
    # * Support is included for a customer id via the :customer option, invoice number via :invoice option, invoice description via :merchant option and memo via :description option
    # * You can force email of receipt with :email_receipt => true
    # * You can force email of merchant receipt with :merchant_receipt => true
    # * You can exclude CVV with :ignore_cvv => true
    # * All transactions use dollar values.
    class QuantumGateway < Gateway
      self.live_url = self.test_url = 'https://secure.quantumgateway.com/cgi/xml_requester.php'

      # visa, master, american_express, discover
      self.supported_cardtypes = %i[visa master american_express discover]
      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.homepage_url = 'http://www.quantumgateway.com'
      self.display_name = 'Quantum Gateway'

      # These are the options that can be used when creating a new Quantum Gateway object.
      #
      # :login =>  Your Quantum Gateway Gateway ID
      #
      # :password =>  Your Quantum Gateway Vault Key or Restrict Key
      #
      # NOTE: For testing supply your test GatewayLogin and GatewayKey
      #
      # :email_receipt => true   if you want a receipt sent to the customer (false be default)
      #
      # :merchant_receipt  => true if you want to override receiving the merchant receipt
      #
      # :ignore_avs => true   ignore both AVS and CVV verification
      # :ignore_cvv => true   don't want to use CVV so continue processing even if CVV would have failed
      #
      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      # Request an authorization for an amount from CyberSource
      #
      def authorize(money, creditcard, options = {})
        setup_address_hash(options)
        commit(build_auth_request(money, creditcard, options), options)
      end

      # Capture an authorization that has previously been requested
      def capture(money, authorization, options = {})
        setup_address_hash(options)
        commit(build_capture_request(money, authorization, options), options)
      end

      # Purchase is an auth followed by a capture
      # You must supply an order_id in the options hash
      def purchase(money, creditcard, options = {})
        setup_address_hash(options)
        commit(build_purchase_request(money, creditcard, options), options)
      end

      def void(identification, options = {})
        commit(build_void_request(identification, options), options)
      end

      def refund(money, identification, options = {})
        commit(build_credit_request(money, identification, options), options)
      end

      def credit(money, identification, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      private

      def setup_address_hash(options)
        options[:billing_address] = options[:billing_address] || options[:address] || {}
      end

      def build_auth_request(money, creditcard, options)
        xml = Builder::XmlMarkup.new
        add_common_credit_card_info(xml, 'AUTH_ONLY')
        add_purchase_data(xml, money)
        add_creditcard(xml, creditcard)
        add_address(xml, creditcard, options[:billing_address], options)
        add_invoice_details(xml, options)
        add_customer_details(xml, options)
        add_memo(xml, options)
        add_business_rules_data(xml)
        xml.target!
      end

      def build_capture_request(money, authorization, options)
        xml = Builder::XmlMarkup.new
        add_common_credit_card_info(xml, 'PREVIOUS_SALE')
        transaction_id, = authorization_parts_from(authorization)
        add_transaction_id(xml, transaction_id)
        xml.target!
      end

      def build_purchase_request(money, creditcard, options)
        xml = Builder::XmlMarkup.new
        add_common_credit_card_info(xml, @options[:ignore_avs] || @options[:ignore_cvv] ? 'SALES' : 'AUTH_CAPTURE')
        add_address(xml, creditcard, options[:billing_address], options)
        add_purchase_data(xml, money)
        add_creditcard(xml, creditcard)
        add_invoice_details(xml, options)
        add_customer_details(xml, options)
        add_memo(xml, options)
        add_business_rules_data(xml)
        xml.target!
      end

      def build_void_request(authorization, options)
        xml = Builder::XmlMarkup.new
        add_common_credit_card_info(xml, 'VOID')
        transaction_id, = authorization_parts_from(authorization)
        add_transaction_id(xml, transaction_id)
        xml.target!
      end

      def build_credit_request(money, authorization, options)
        xml = Builder::XmlMarkup.new
        add_common_credit_card_info(xml, 'RETURN')
        add_purchase_data(xml, money)
        transaction_id, cc = authorization_parts_from(authorization)
        add_transaction_id(xml, transaction_id)
        xml.tag! 'CreditCardNumber', cc
        xml.target!
      end

      def add_common_credit_card_info(xml, process_type)
        xml.tag! 'RequestType', 'ProcessSingleTransaction'
        xml.tag! 'TransactionType', 'CREDIT'
        xml.tag! 'PaymentType', 'CC'
        xml.tag! 'ProcessType', process_type
      end

      def add_business_rules_data(xml)
        xml.tag!('CustomerEmail', @options[:email_receipt] ? 'Y' : 'N')
        xml.tag!('MerchantEmail', @options[:merchant_receipt] ? 'Y' : 'N')
      end

      def add_invoice_details(xml, options)
        xml.tag! 'InvoiceNumber', options[:invoice]
        xml.tag! 'InvoiceDescription', options[:merchant]
      end

      def add_customer_details(xml, options)
        xml.tag! 'CustomerID', options[:customer]
      end

      def add_transaction_id(xml, transaction_id)
        xml.tag! 'TransactionID', transaction_id
      end

      def add_memo(xml, options)
        xml.tag! 'Memo', options[:description]
      end

      def add_purchase_data(xml, money = 0)
        xml.tag! 'Amount', amount(money)
        xml.tag! 'TransactionDate', Time.now
      end

      def add_address(xml, creditcard, address, options, shipTo = false)
        xml.tag! 'FirstName', creditcard.first_name
        xml.tag! 'LastName', creditcard.last_name
        xml.tag! 'Address', address[:address1] # => there is no support for address2 in quantum
        xml.tag! 'City', address[:city]
        xml.tag! 'State', address[:state]
        xml.tag! 'ZipCode', address[:zip]
        xml.tag! 'Country', address[:country]
        xml.tag! 'EmailAddress', options[:email]
        xml.tag! 'IPAddress', options[:ip]
      end

      def add_creditcard(xml, creditcard)
        xml.tag! 'PaymentType', 'CC'
        xml.tag! 'CreditCardNumber', creditcard.number
        xml.tag! 'ExpireMonth', format(creditcard.month, :two_digits)
        xml.tag! 'ExpireYear', format(creditcard.year, :four_digits)
        xml.tag!('CVV2', creditcard.verification_value) unless @options[:ignore_cvv] || creditcard.verification_value.blank?
      end

      # Where we actually build the full SOAP request using builder
      def build_request(body, options)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'QGWRequest' do
          xml.tag! 'Authentication' do
            xml.tag! 'GatewayLogin', @options[:login]
            xml.tag! 'GatewayKey', @options[:password]
          end
          xml.tag! 'Request' do
            xml << body
          end
        end
        xml.target!
      end

      # Contact CyberSource, make the SOAP request, and parse the reply into a Response object
      def commit(request, options)
        headers = { 'Content-Type' => 'text/xml' }
        response = parse(ssl_post(self.live_url, build_request(request, options), headers))

        success = response[:request_status] == 'Success'
        message = response[:request_message]

        if success # => checking for connectivity success first
          success = %w(APPROVED FORCED VOIDED).include?(response[:Status])
          message = response[:StatusDescription]
          authorization = success ? authorization_for(response) : nil
        end

        Response.new(success, message, response,
          test: test?,
          authorization: authorization,
          avs_result: { code: response[:AVSResponseCode] },
          cvv_result: response[:CVV2ResponseCode]
        )
      end

      # Parse the SOAP response
      # Technique inspired by the Paypal Gateway
      def parse(xml)
        reply = {}

        begin
          xml = REXML::Document.new(xml)

          root = REXML::XPath.first(xml, '//QGWRequest/ResponseSummary')
          parse_element(reply, root)
          reply[:request_status] = reply[:Status]
          reply[:request_message] = "#{reply[:Status]}: #{reply[:StatusDescription]}"

          if root = REXML::XPath.first(xml, '//QGWRequest/Result')
            root.elements.to_a.each do |node|
              parse_element(reply, node)
            end
          end
        rescue Exception
          reply[:request_status] = 'Failure'
          reply[:request_message] = 'Failure: There was a problem parsing the response XML'
        end

        return reply
      end

      def parse_element(reply, node)
        if node.has_elements?
          node.elements.each { |e| parse_element(reply, e) }
        else
          if /item/.match?(node.parent.name)
            parent = node.parent.name + (node.parent.attributes['id'] ? '_' + node.parent.attributes['id'] : '')
            reply[(parent + '_' + node.name).to_sym] = node.text
          else
            reply[node.name.to_sym] = node.text
          end
        end
        return reply
      end

      def authorization_for(reply)
        "#{reply[:TransactionID]};#{reply[:CreditCardNumber]}"
      end

      def authorization_parts_from(authorization)
        authorization.split(/;/)
      end
    end
  end
end
