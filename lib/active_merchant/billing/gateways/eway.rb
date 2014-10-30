require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Public: For more information on the Eway Gateway please visit their
    # {Developers Area}[http://www.eway.com.au/developers/api/direct-payments]
    class EwayGateway < Gateway
      self.live_url = 'https://www.eway.com.au'

      self.money_format = :cents
      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]
      self.homepage_url = 'http://www.eway.com.au/'
      self.display_name = 'eWAY'

      # Public: Create a new Eway Gateway.
      # options - A hash of options:
      #           :login     - Your Customer ID.
      #           :password  - Your XML Refund Password that you
      #                        specified on the Eway site. (optional)
      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def purchase(money, creditcard, options = {})
        requires_address!(options)

        post = {}
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_customer_id(post)
        add_invoice_data(post, options)
        add_non_optional_data(post)
        add_amount(post, money)
        post[:CustomerEmail] = options[:email]

        commit(purchase_url(post[:CVN]), money, post)
      end

      def refund(money, authorization, options={})
        post = {}

        add_customer_id(post)
        add_amount(post, money)
        add_non_optional_data(post)
        post[:OriginalTrxnNumber] = authorization
        post[:RefundPassword] = @options[:password]
        post[:CardExpiryMonth] = nil
        post[:CardExpiryYear] = nil

        commit(refund_url, money, post)
      end

      private
      def requires_address!(options)
        raise ArgumentError.new("Missing eWay required parameters: address or billing_address") unless (options.has_key?(:address) or options.has_key?(:billing_address))
      end

      def add_creditcard(post, creditcard)
        post[:CardNumber]  = creditcard.number
        post[:CardExpiryMonth]  = sprintf("%.2i", creditcard.month)
        post[:CardExpiryYear] = sprintf("%.4i", creditcard.year)[-2..-1]
        post[:CustomerFirstName] = creditcard.first_name
        post[:CustomerLastName]  = creditcard.last_name
        post[:CardHoldersName] = creditcard.name

        post[:CVN] = creditcard.verification_value if creditcard.verification_value?
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:CustomerAddress]    = [ address[:address1], address[:address2], address[:city], address[:state], address[:country] ].compact.join(', ')
          post[:CustomerPostcode]   = address[:zip]
        end
      end

      def add_customer_id(post)
        post[:CustomerID] = @options[:login]
      end

      def add_invoice_data(post, options)
        post[:CustomerInvoiceRef] = options[:order_id]
        post[:CustomerInvoiceDescription] = options[:description]
      end

      def add_amount(post, money)
        post[:TotalAmount] = amount(money)
      end

      def add_non_optional_data(post)
        post[:Option1] = nil
        post[:Option2] = nil
        post[:Option3] = nil
        post[:TrxnNumber] = nil
      end

      def commit(url, money, parameters)
        raw_response = ssl_post(url, post_data(parameters))
        response = parse(raw_response)

        Response.new(success?(response),
          message_from(response[:ewaytrxnerror]),
          response,
          :authorization => response[:ewaytrxnnumber],
          :test => test?
        )
      end

      def success?(response)
        response[:ewaytrxnstatus] == "True"
      end

      def parse(xml)
        response = {}
        xml = REXML::Document.new(xml)
        xml.elements.each('//ewayResponse/*') do |node|
          response[node.name.downcase.to_sym] = normalize(node.text)
        end unless xml.root.nil?

        response
      end

      def post_data(parameters = {})
        xml   = REXML::Document.new
        root  = xml.add_element("ewaygateway")

        parameters.each do |key, value|
          root.add_element("eway#{key}").text = value
        end
        xml.to_s
      end

      def message_from(message)
        return '' if message.blank?
        MESSAGES[message[0,2]] || message
      end

      def purchase_url(cvn)
        suffix = test? ? 'xmltest/testpage.asp' : 'xmlpayment.asp'
        gateway_part = cvn ? 'gateway_cvn' : 'gateway'
        "#{live_url}/#{gateway_part}/#{suffix}"
      end

      def refund_url
        suffix = test? ? 'xmltest/refund_test.asp' : 'xmlpaymentrefund.asp'
        "#{live_url}/gateway/#{suffix}"
      end

      MESSAGES = {
        "00" => "Transaction Approved",
        "01" => "Refer to Issuer",
        "02" => "Refer to Issuer, special",
        "03" => "No Merchant",
        "04" => "Pick Up Card",
        "05" => "Do Not Honour",
        "06" => "Error",
        "07" => "Pick Up Card, Special",
        "08" => "Honour With Identification",
        "09" => "Request In Progress",
        "10" => "Approved For Partial Amount",
        "11" => "Approved, VIP",
        "12" => "Invalid Transaction",
        "13" => "Invalid Amount",
        "14" => "Invalid Card Number",
        "15" => "No Issuer",
        "16" => "Approved, Update Track 3",
        "19" => "Re-enter Last Transaction",
        "21" => "No Action Taken",
        "22" => "Suspected Malfunction",
        "23" => "Unacceptable Transaction Fee",
        "25" => "Unable to Locate Record On File",
        "30" => "Format Error",
        "31" => "Bank Not Supported By Switch",
        "33" => "Expired Card, Capture",
        "34" => "Suspected Fraud, Retain Card",
        "35" => "Card Acceptor, Contact Acquirer, Retain Card",
        "36" => "Restricted Card, Retain Card",
        "37" => "Contact Acquirer Security Department, Retain Card",
        "38" => "PIN Tries Exceeded, Capture",
        "39" => "No Credit Account",
        "40" => "Function Not Supported",
        "41" => "Lost Card",
        "42" => "No Universal Account",
        "43" => "Stolen Card",
        "44" => "No Investment Account",
        "51" => "Insufficient Funds",
        "52" => "No Cheque Account",
        "53" => "No Savings Account",
        "54" => "Expired Card",
        "55" => "Incorrect PIN",
        "56" => "No Card Record",
        "57" => "Function Not Permitted to Cardholder",
        "58" => "Function Not Permitted to Terminal",
        "59" => "Suspected Fraud",
        "60" => "Acceptor Contact Acquirer",
        "61" => "Exceeds Withdrawal Limit",
        "62" => "Restricted Card",
        "63" => "Security Violation",
        "64" => "Original Amount Incorrect",
        "66" => "Acceptor Contact Acquirer, Security",
        "67" => "Capture Card",
        "75" => "PIN Tries Exceeded",
        "82" => "CVV Validation Error",
        "90" => "Cutoff In Progress",
        "91" => "Card Issuer Unavailable",
        "92" => "Unable To Route Transaction",
        "93" => "Cannot Complete, Violation Of The Law",
        "94" => "Duplicate Transaction",
        "96" => "System Error"
      }
    end
  end
end
