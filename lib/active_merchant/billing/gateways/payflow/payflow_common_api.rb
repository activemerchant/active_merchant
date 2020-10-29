require 'nokogiri'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PayflowCommonAPI
      def self.included(base)
        base.default_currency = 'USD'

        base.class_attribute :partner

        # Set the default partner to PayPal
        base.partner = 'PayPal'

        base.supported_countries = %w[US CA NZ AU]

        base.class_attribute :timeout
        base.timeout = 60

        base.test_url = 'https://pilot-payflowpro.paypal.com'
        base.live_url = 'https://payflowpro.paypal.com'

        # Enable safe retry of failed connections
        # Payflow is safe to retry because retried transactions use the same
        # X-VPS-Request-ID header. If a transaction is detected as a duplicate
        # only the original transaction data will be used by Payflow, and the
        # subsequent Responses will have a :duplicate parameter set in the params
        # hash.
        base.retry_safe = true

        # Send Payflow requests to PayPal directly by activating the NVP protocol.
        # Valid XMLPay documents may have issues being parsed correctly by
        # Payflow but will be accepted by PayPal if a PAYPAL-NVP request header
        # is declared.
        base.class_attribute :use_paypal_nvp
        base.use_paypal_nvp = false
      end

      XMLNS = 'http://www.paypal.com/XMLPay'

      CARD_MAPPING = {
        visa: 'Visa',
        master: 'MasterCard',
        discover: 'Discover',
        american_express: 'Amex',
        jcb: 'JCB',
        diners_club: 'DinersClub'
      }

      TRANSACTIONS = {
        purchase: 'Sale',
        authorization: 'Authorization',
        capture: 'Capture',
        void: 'Void',
        credit: 'Credit'
      }

      CVV_CODE = {
        'Match' => 'M',
        'No Match' => 'N',
        'Service Not Available' => 'U',
        'Service not Requested' => 'P'
      }

      def initialize(options = {})
        requires!(options, :login, :password)

        options[:partner] = partner if options[:partner].blank?
        super
      end

      def capture(money, authorization, options = {})
        request = build_reference_request(:capture, money, authorization, options)
        commit(request, options)
      end

      def void(authorization, options = {})
        request = build_reference_request(:void, nil, authorization, options)
        commit(request, options)
      end

      private

      def build_request(body, options = {})
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'XMLPayRequest', 'Timeout' => timeout.to_s, 'version' => '2.1', 'xmlns' => XMLNS do
          xml.tag! 'RequestData' do
            xml.tag! 'Vendor', @options[:login]
            xml.tag! 'Partner', @options[:partner]
            if options[:request_type] == :recurring
              xml << body
            else
              xml.tag! 'Transactions' do
                xml.tag! 'Transaction', 'CustRef' => options[:customer] do
                  xml.tag! 'Verbosity', @options[:verbosity] || 'MEDIUM'
                  xml << body
                end
              end
            end
          end
          xml.tag! 'RequestAuth' do
            xml.tag! 'UserPass' do
              xml.tag! 'User', !@options[:user].blank? ? @options[:user] : @options[:login]
              xml.tag! 'Password', @options[:password]
            end
          end
        end
        xml.target!
      end

      def build_reference_request(action, money, authorization, options)
        xml = Builder::XmlMarkup.new
        xml.tag! TRANSACTIONS[action] do
          xml.tag! 'PNRef', authorization

          unless money.nil?
            xml.tag! 'Invoice' do
              xml.tag!('TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money))
              xml.tag!('Description', options[:description]) unless options[:description].blank?
              xml.tag!('Comment', options[:comment]) unless options[:comment].blank?
              xml.tag!('ExtData', 'Name' => 'COMMENT2', 'Value' => options[:comment2]) unless options[:comment2].blank?
              xml.tag!(
                'ExtData',
                'Name' => 'CAPTURECOMPLETE',
                'Value' => options[:capture_complete]
              ) unless options[:capture_complete].blank?
            end
          end
        end

        xml.target!
      end

      def add_address(xml, tag, address, options)
        return if address.nil?

        xml.tag! tag do
          xml.tag! 'Name', address[:name] unless address[:name].blank?
          xml.tag! 'EMail', options[:email] unless options[:email].blank?
          xml.tag! 'Phone', address[:phone] unless address[:phone].blank?
          xml.tag! 'CustCode', options[:customer] if !options[:customer].blank? && tag == 'BillTo'
          xml.tag! 'PONum', options[:po_number] if !options[:po_number].blank? && tag == 'BillTo'

          xml.tag! 'Address' do
            xml.tag! 'Street', address[:address1] unless address[:address1].blank?
            xml.tag! 'Street2', address[:address2] unless address[:address2].blank?
            xml.tag! 'City', address[:city] unless address[:city].blank?
            xml.tag! 'State', address[:state].blank? ? 'N/A' : address[:state]
            xml.tag! 'Country', address[:country] unless address[:country].blank?
            xml.tag! 'Zip', address[:zip] unless address[:zip].blank?
          end
        end
      end

      def parse(data)
        response = {}
        xml = Nokogiri::XML(data)
        xml.remove_namespaces!
        root = xml.xpath('//ResponseData')

        # REXML::XPath in Ruby 1.8.6 is now unable to match nodes based on their attributes
        tx_result = root.xpath('.//TransactionResult').first

        response[:duplicate] = true if tx_result && tx_result.attributes['Duplicate'].to_s == 'true'

        root.xpath('.//*').each do |node|
          parse_element(response, node)
        end

        response
      end

      def parse_element(response, node)
        node_name = node.name.underscore.to_sym
        case
        when node_name == :rp_payment_result
          # Since we'll have multiple history items, we can't just flatten everything
          # down as we do everywhere else. RPPaymentResult elements are not contained
          # in an RPPaymentResults element so we'll come here multiple times
          response[node_name] ||= []
          response[node_name] << (payment_result_response = {})
          node.xpath('.//*').each { |e| parse_element(payment_result_response, e) }
        when node.xpath('.//*').to_a.any?
          node.xpath('.//*').each { |e| parse_element(response, e) }
        when /amt$/.match?(node_name.to_s)
          # *Amt elements don't put the value in the #text - instead they use a Currency attribute
          response[node_name] = node.attributes['Currency'].to_s
        when node_name == :ext_data
          response[node.attributes['Name'].to_s.underscore.to_sym] = node.attributes['Value'].to_s
        else
          response[node_name] = node.text
        end
      end

      def build_headers(content_length)
        headers = {
          'Content-Type' => 'text/xml',
          'Content-Length' => content_length.to_s,
          'X-VPS-Client-Timeout' => timeout.to_s,
          'X-VPS-VIT-Integration-Product' => 'ActiveMerchant',
          'X-VPS-VIT-Runtime-Version' => RUBY_VERSION,
          'X-VPS-Request-ID' => SecureRandom.hex(16)
        }

        headers['PAYPAL-NVP'] = 'Y' if self.use_paypal_nvp
        headers
      end

      def commit(request_body, options = {})
        request = build_request(request_body, options)
        headers = build_headers(request.size)

        response = parse(ssl_post(test? ? self.test_url : self.live_url, request, headers))

        build_response(
          success_for(response),
          response[:message], response,
          test: test?,
          authorization: response[:pn_ref] || response[:rp_ref],
          cvv_result: CVV_CODE[response[:cv_result]],
          avs_result: { code: response[:avs_result] },
          fraud_review: under_fraud_review?(response)
        )
      end

      def success_for(response)
        %w(0 126).include?(response[:result])
      end

      def under_fraud_review?(response)
        (response[:result] == '126')
      end
    end
  end
end
