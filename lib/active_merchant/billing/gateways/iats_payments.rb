module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IatsPaymentsGateway < Gateway
      class_attribute :live_na_url, :live_uk_url

      self.live_na_url = 'https://www.iatspayments.com/NetGate'
      self.live_uk_url = 'https://www.uk.iatspayments.com/NetGate'

      self.supported_countries = %w(AU BR CA CH DE DK ES FI FR GR HK IE IT NL NO PT SE SG TR GB US TH ID PH BE)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'http://home.iatspayments.com/'
      self.display_name = 'iATS Payments'

      ACTIONS = {
        purchase: 'ProcessCreditCard',
        purchase_check: 'ProcessACHEFT',
        purchase_customer_code: 'ProcessCreditCardWithCustomerCode',
        refund: 'ProcessCreditCardRefundWithTransactionId',
        refund_check: 'ProcessACHEFTRefundWithTransactionId',
        store: 'CreateCreditCardCustomerCode',
        unstore: 'DeleteCustomerCode'
      }

      def initialize(options = {})
        if options[:login]
          ActiveMerchant.deprecated("The 'login' option is deprecated in favor of 'agent_code' and will be removed in a future version.")
          options[:agent_code] = options[:login]
        end

        options[:region] = 'na' unless options[:region]

        requires!(options, :agent_code, :password, :region)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_ip(post, options)
        add_description(post, options)
        add_customer_details(post, options)

        commit(determine_purchase_type(payment), post)
      end

      def refund(money, authorization, options = {})
        post = {}
        transaction_id, payment_type = split_authorization(authorization)
        post[:transaction_id] = transaction_id
        add_invoice(post, -money, options)
        add_ip(post, options)
        add_description(post, options)

        commit((payment_type == 'check' ? :refund_check : :refund), post)
      end

      def store(credit_card, options = {})
        post = {}
        add_payment(post, credit_card)
        add_address(post, options)
        add_ip(post, options)
        add_description(post, options)
        add_store_defaults(post)

        commit(:store, post)
      end

      def unstore(authorization, options = {})
        post = {}
        post[:customer_code] = authorization
        add_ip(post, options)

        commit(:unstore, post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<agentCode>).+(</agentCode>)), '\1[FILTERED]\2').
          gsub(%r((<password>).+(</password>)), '\1[FILTERED]\2').
          gsub(%r((<creditCardNum>).+(</creditCardNum>)), '\1[FILTERED]\2').
          gsub(%r((<cvv2>).+(</cvv2>)), '\1[FILTERED]\2').
          gsub(%r((<accountNum>).+(</accountNum>)), '\1[FILTERED]\2')
      end

      private

      def determine_purchase_type(payment)
        if payment.is_a?(String)
          :purchase_customer_code
        elsif payment.is_a?(Check)
          :purchase_check
        else
          :purchase
        end
      end

      def add_ip(post, options)
        post[:customer_ip_address] = options[:ip] if options.has_key?(:ip)
      end

      def add_address(post, options)
        billing_address = options[:billing_address] || options[:address]
        if billing_address
          post[:address] = billing_address[:address1]
          post[:city] = billing_address[:city]
          post[:state] = billing_address[:state]
          post[:zip_code] = billing_address[:zip]
          post[:phone] = billing_address[:phone] if billing_address[:phone]
          post[:email] = billing_address[:email] if billing_address[:email]
          post[:country] = billing_address[:country] if billing_address[:country]
        end
      end

      def add_invoice(post, money, options)
        post[:invoice_num] = options[:order_id] if options[:order_id]
        post[:total] = amount(money)
      end

      def add_description(post, options)
        post[:comment] = options[:description] if options[:description]
      end

      def add_payment(post, payment)
        if payment.is_a?(String)
          post[:customer_code] = payment
        elsif payment.is_a?(Check)
          add_check(post, payment)
        else
          add_credit_card(post, payment)
        end
      end

      def add_credit_card(post, payment)
        post[:first_name] = payment.first_name
        post[:last_name] = payment.last_name
        post[:credit_card_num] = payment.number
        post[:credit_card_expiry] = expdate(payment)
        post[:cvv2] = payment.verification_value if payment.verification_value?
        post[:mop] = creditcard_brand(payment.brand)
      end

      def add_check(post, payment)
        post[:first_name] = payment.first_name
        post[:last_name] = payment.last_name
        post[:account_num] = "#{payment.routing_number}#{payment.account_number}"
        post[:account_type] = payment.account_type.upcase
      end

      def add_store_defaults(post)
        post[:recurring] = false
        post[:begin_date] = Time.now.xmlschema
        post[:end_date] = Time.now.xmlschema
        post[:amount] = 0
      end

      def add_customer_details(post, options)
        post[:email] = options[:email] if options[:email]
      end

      def expdate(creditcard)
        year  = sprintf('%.4i', creditcard.year)
        month = sprintf('%.2i', creditcard.month)

        "#{month}/#{year[-2..-1]}"
      end

      def creditcard_brand(brand)
        case brand
        when 'visa' then 'VISA'
        when 'master' then 'MC'
        when 'discover' then 'DSC'
        when 'american_express' then 'AMX'
        when 'maestro' then 'MAESTR'
        else
          raise "Unhandled credit card brand #{brand}"
        end
      end

      def commit(action, parameters)
        response = parse(ssl_post(url(action), post_data(action, parameters),
          { 'Content-Type' => 'application/soap+xml; charset=utf-8' }))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(action, response),
          test: test?
        )
      end

      def endpoints
        {
          purchase: 'ProcessLinkv3.asmx',
          purchase_check: 'ProcessLinkv3.asmx',
          purchase_customer_code: 'ProcessLinkv3.asmx',
          refund: 'ProcessLinkv3.asmx',
          refund_check: 'ProcessLinkv3.asmx',
          store: 'CustomerLinkv3.asmx',
          unstore: 'CustomerLinkv3.asmx'
        }
      end

      def url(action)
        base_url = @options[:region] == 'uk' ? live_uk_url : live_na_url
        "#{base_url}/#{endpoints[action]}?op=#{ACTIONS[action]}"
      end

      def parse(body)
        response = {}
        hashify_xml!(body, response)
        response
      end

      def dexmlize_param_name(name)
        names = {
          'AUTHORIZATIONRESULT' => :authorization_result,
          'SETTLEMENTBATCHDATE' => :settlement_batch_date,
          'SETTLEMENTDATE' => :settlement_date,
          'TRANSACTIONID' => :transaction_id
        }
        names[name] || name.to_s.downcase.intern
      end

      def hashify_xml!(xml, response)
        xml = REXML::Document.new(xml)

        xml.elements.each('//IATSRESPONSE/*') do |node|
          recursively_parse_element(node, response)
        end
      end

      def recursively_parse_element(node, response)
        if node.has_elements?
          node.elements.each { |n| recursively_parse_element(n, response) }
        else
          response[dexmlize_param_name(node.name)] = (node.text ? node.text.strip : nil)
        end
      end

      def successful_result_message?(response)
        response[:authorization_result] ? response[:authorization_result].start_with?('OK') : false
      end

      def success_from(response)
        response[:status] == 'Success' && successful_result_message?(response)
      end

      def message_from(response)
        if !successful_result_message?(response) && response[:authorization_result]
          return response[:authorization_result].strip
        elsif response[:status] == 'Failure'
          return response[:errors]
        else
          response[:status]
        end
      end

      def authorization_from(action, response)
        if %i[store unstore].include?(action)
          response[:customercode]
        elsif [:purchase_check].include?(action)
          response[:transaction_id] ? "#{response[:transaction_id]}|check" : nil
        else
          response[:transaction_id]
        end
      end

      def split_authorization(authorization)
        authorization.split('|')
      end

      def envelope_namespaces
        {
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:soap12' => 'http://www.w3.org/2003/05/soap-envelope'
        }
      end

      def post_data(action, parameters = {})
        xml = Builder::XmlMarkup.new
        xml.instruct!(:xml, version: '1.0', encoding: 'utf-8')
        xml.tag! 'soap12:Envelope', envelope_namespaces do
          xml.tag! 'soap12:Body' do
            xml.tag! ACTIONS[action], { 'xmlns' => 'https://www.iatspayments.com/NetGate/' } do
              xml.tag!('agentCode', @options[:agent_code])
              xml.tag!('password', @options[:password])
              parameters.each do |name, value|
                xml.tag!(xmlize_param_name(name), value)
              end
            end
          end
        end
        xml.target!
      end

      def xmlize_param_name(name)
        names = { customer_ip_address: 'customerIPAddress' }
        names[name] || name.to_s.camelcase(:lower)
      end
    end
  end
end
