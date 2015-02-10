module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Flo2cashSimpleGateway < Gateway
      self.display_name = 'Flo2Cash Simple'
      self.homepage_url = 'http://www.flo2cash.co.nz/'

      self.test_url = 'https://demo.flo2cash.co.nz/ws/paymentws.asmx'
      self.live_url = 'https://secure.flo2cash.co.nz/ws/paymentws.asmx'

      self.supported_countries = ['NZ']
      self.default_currency = 'NZD'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      def initialize(options={})
        requires!(options, :username, :password, :account_id)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("purchase", post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit("refund", post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<Password>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<CardNumber>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<CardCSC>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency: #{k}")}
      CURRENCY_CODES["NZD"] = "554"

      def add_invoice(post, money, options)
        post[:Amount] = amount(money)
        post[:Reference] = options[:invoice]
        post[:Particular] = options[:description]
      end

      def add_payment_method(post, payment_method)
        post[:CardNumber] = payment_method.number
        post[:CardType] = payment_method.brand
        post[:CardExpiry] = format(payment_method.month, :two_digits) + format(payment_method.year, :two_digits)
        post[:CardHolderName] = payment_method.name
        post[:CardCSC] = payment_method.verification_value
      end

      def add_customer_data(post, options)
        if(billing_address = (options[:billing_address] || options[:address]))
          post[:Email] = billing_address[:email]
        end
      end

      def add_reference(post, authorization)
        post[:OriginalTransactionId] = authorization
      end

      ACTIONS = {
        "purchase" => "ProcessPurchase",
        "refund" => "ProcessRefund",
      }

      def commit(action, post)
        post[:Username] = @options[:username]
        post[:Password] = @options[:password]
        post[:AccountId] = @options[:account_id]
        process_action = ACTIONS[action] if ACTIONS[action]

        data = build_request(process_action, post)
        raw = parse(ssl_post(url(action), data, headers(process_action)), process_action)

        succeeded = success_from(raw[:status])
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          :authorization => authorization_from(action, raw[:transaction_id], post[:OriginalTransactionId]),
          :error_code => error_code_from(succeeded, raw),
          :test => test?
        )
      end

      def headers(action)
        {
          'Content-Type'  => 'application/soap+xml; charset=utf-8',
          'SOAPAction'    => %{"http://www.flo2cash.co.nz/webservices/paymentwebservice/#{action}"}
        }
      end

      def build_request(action, post)
        xml = Builder::XmlMarkup.new :indent => 2
        post.each do |field, value|
          xml.tag!(field, value)
        end
        body = xml.target!
        envelope_wrap(action, body)
      end

      def envelope_wrap(action, body)
        <<-EOS
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <#{action} xmlns="http://www.flo2cash.co.nz/webservices/paymentwebservice">
      #{body}
    </#{action}>
  </soap12:Body>
</soap12:Envelope>
        EOS
      end

      def url(action)
        (test? ? test_url : live_url)
      end

      def parse(body, action)
        response = {}
        xml = REXML::Document.new(body)
        root = REXML::XPath.first(xml, "//#{action}Response")

        root.elements.to_a.each do |node|
          parse_element(response, node)
        end if root

        response
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def success_from(response)
        response == 'SUCCESSFUL'
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response[:message] || "Unable to read error message"
        end
      end

      def authorization_from(action, current, original)
        # Refunds require the authorization from the authorize() of the MultiResponse.
        if action == 'capture'
          original
        else
          current
        end
      end

      STANDARD_ERROR_CODE_MAPPING = {
        'Transaction Declined - Expired Card' => STANDARD_ERROR_CODE[:expired_card],
        'Bank Declined Transaction' => STANDARD_ERROR_CODE[:card_declined],
        'Insufficient Funds' => STANDARD_ERROR_CODE[:card_declined],
        'Transaction Declined - Bank Error' => STANDARD_ERROR_CODE[:processing_error],
        'No Reply from Bank' => STANDARD_ERROR_CODE[:processing_error],
      }

      def error_code_from(succeeded, response)
        succeeded ? nil : STANDARD_ERROR_CODE_MAPPING[response[:message]]
      end
    end
  end
end
