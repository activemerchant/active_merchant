module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IatsPaymentsGateway < Gateway
      class_attribute :live_na_url, :live_uk_url

      self.live_na_url = 'https://www.iatspayments.com/NetGate/ProcessLink.asmx'
      self.live_uk_url = 'https://www.uk.iatspayments.com/NetGate/ProcessLink.asmx'

      self.supported_countries = %w(AU CA CH DE DK ES FI FR GR HK IE IT JP NL NO NZ PT SE SG TR GB US)
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://home.iatspayments.com/'
      self.display_name = 'iATS Payments'

      def initialize(options={})
        if(options[:login])
          deprecated("The 'login' option is deprecated in favor of 'agent_code' and will be removed in a future version.")
          options[:agent_code] = options[:login]
        end

        options[:region] = 'na' unless options[:region]

        requires!(options, :agent_code, :password, :region)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)

        commit('ProcessCreditCardV1', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        post = {}
        post[:transaction_id] = authorization
        add_customer_data(post, options)
        add_invoice(post, -money, options)

        commit('ProcessCreditCardRefundWithTransactionIdV1', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      private

      def add_customer_data(post, options)
        post[:customer_ip_address] = options[:ip] if options.has_key?(:ip)
      end

      def add_address(post, options)
        billing_address = options[:billing_address] || options[:address]
        if(billing_address)
          post[:address] = billing_address[:address1]
          post[:city] = billing_address[:city]
          post[:state] = billing_address[:state]
          post[:zip_code] = billing_address[:zip]
        end
      end

      def add_invoice(post, money, options)
        post[:invoice_num] = options[:order_id] if options[:order_id]
        post[:total] = amount(money)
        post[:comment] = options[:description] if options[:description]
      end

      def add_payment(post, payment)
        post[:first_name] = payment.first_name
        post[:last_name] = payment.last_name
        post[:credit_card_num] = payment.number
        post[:credit_card_expiry] = expdate(payment)
        post[:cvv2] = payment.verification_value if payment.verification_value?
        post[:mop] = creditcard_brand(payment.brand)
      end

      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}/#{year[-2..-1]}"
      end

      def creditcard_brand(brand)
        case brand
        when "visa" then "VISA"
        when "master" then "MC"
        when "discover" then "DSC"
        when "american_express" then "AMX"
        when "maestro" then "MAESTR"
        else
          raise "Unhandled credit card brand #{brand}"
        end
      end

      def commit(action, parameters)
        response = parse(ssl_post(url(action), post_data(action, parameters),
         { 'Content-Type' => 'application/soap+xml; charset=utf-8'}))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def url(action)
        base_url = @options[:region] == 'uk' ? live_uk_url : live_na_url
        "#{base_url}?op=#{action}"
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

        # Purchase, refund
        xml.elements.each("//IATSRESPONSE/*") do |node|
          recursively_parse_element(node, response)
        end
      end

      # Flatten nested XML structures
      def recursively_parse_element(node, response)
        if(node.has_elements?)
          node.elements.each { |n| recursively_parse_element(n, response) }
        else
          response[dexmlize_param_name(node.name)] = (node.text ? node.text.strip : nil)
        end
      end

      def successful_result_message?(response)
        response[:authorization_result].start_with?('OK')
      end

      def success_from(response)
        response[:status] == "Success" && successful_result_message?(response)
      end

      def message_from(response)
        if(!successful_result_message?(response))
          return response[:authorization_result].strip
        elsif(response[:status] == 'Failure')
          return response[:errors]
        else
          response[:status]
        end
      end

      def authorization_from(response)
        response[:transaction_id]
      end

      ENVELOPE_NAMESPACES = {
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
        "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
        "xmlns:soap12" => "http://www.w3.org/2003/05/soap-envelope"
      }

      def post_data(action, parameters = {})
        xml = Builder::XmlMarkup.new
        xml.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
        xml.tag! 'soap12:Envelope', ENVELOPE_NAMESPACES do
          xml.tag! 'soap12:Body' do
            xml.tag! action, { "xmlns" => "https://www.iatspayments.com/NetGate/" } do
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
