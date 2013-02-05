module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FirstdataE4Gateway < Gateway
      self.test_url = "https://api.demo.globalgatewaye4.firstdata.com/transaction"
      self.live_url = "https://api.globalgatewaye4.firstdata.com/transaction"

      TRANSACTIONS = {
        :sale          => "00",
        :authorization => "01",
        :capture       => "32",
        :void          => "33",
        :credit        => "34"
      }

      POST_HEADERS = {
        "Accepts" => "application/xml",
        "Content-Type" => "application/xml"
      }

      SUCCESS = "true"

      SENSITIVE_FIELDS = [:verification_str2, :expiry_date, :card_number]

      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :discover]
      self.supported_countries = ["CA", "US"]
      self.default_currency = "USD"
      self.homepage_url = "http://www.firstdata.com"
      self.display_name = "FirstData Global Gateway e4"

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options

        super
      end

      def authorize(money, credit_card, options = {})
        commit(:authorization, build_sale_or_authorization_request(money, credit_card, options))
      end

      def purchase(money, credit_card, options = {})
        commit(:sale, build_sale_or_authorization_request(money, credit_card, options))
      end

      def capture(money, authorization, options = {})
        commit(:capture, build_capture_or_credit_request(money, authorization, options))
      end

      def void(authorization, options = {})
        commit(:void, build_capture_or_credit_request(money_from_authorization(authorization), authorization, options))
      end

      def refund(money, authorization, options = {})
        commit(:credit, build_capture_or_credit_request(money, authorization, options))
      end

      private

      def build_request(action, body)
        xml = Builder::XmlMarkup.new

        xml.instruct!
        xml.tag! "Transaction" do
          add_credentials(xml)
          add_transaction_type(xml, action)
          xml << body
        end

        xml.target!
      end

      def build_sale_or_authorization_request(money, credit_card, options)
        xml = Builder::XmlMarkup.new

        add_amount(xml, money)
        add_credit_card(xml, credit_card)
        add_customer_data(xml, options)
        add_invoice(xml, options)

        xml.target!
      end

      def build_capture_or_credit_request(money, identification, options)
        xml = Builder::XmlMarkup.new

        add_identification(xml, identification)
        add_amount(xml, money)
        add_customer_data(xml, options)

        xml.target!
      end

      def add_credentials(xml)
        xml.tag! "ExactID", @options[:login]
        xml.tag! "Password", @options[:password]
      end

      def add_transaction_type(xml, action)
        xml.tag! "Transaction_Type", TRANSACTIONS[action]
      end

      def add_identification(xml, identification)
        authorization_num, transaction_tag, _ = identification.split(";")

        xml.tag! "Authorization_Num", authorization_num
        xml.tag! "Transaction_Tag", transaction_tag
      end

      def add_amount(xml, money)
        xml.tag! "DollarAmount", amount(money)
      end

      def add_credit_card(xml, credit_card)
        xml.tag! "Card_Number", credit_card.number
        xml.tag! "Expiry_Date", expdate(credit_card)
        xml.tag! "CardHoldersName", credit_card.name
        xml.tag! "CardType", credit_card.brand

        if credit_card.verification_value?
          xml.tag! "CVD_Presence_Ind", "1"
          xml.tag! "VerificationStr2", credit_card.verification_value
        end
      end

      def add_customer_data(xml, options)
        xml.tag! "Customer_Ref", options[:customer] if options[:customer]
        xml.tag! "Client_IP", options[:ip] if options[:ip]
        xml.tag! "Client_Email", options[:email] if options[:email]
      end

      def add_address(xml, options)
        if address = (options[:billing_address] || options[:address])
          xml.tag! "ZipCode", address[:zip]
        end
      end

      def add_invoice(xml, options)
        xml.tag! "Reference_No", options[:order_id]
        xml.tag! "Reference_3",  options[:description] if options[:description]
      end

      def expdate(credit_card)
        "#{format(credit_card.month, :two_digits)}#{format(credit_card.year, :two_digits)}"
      end

      def commit(action, request)
        url = (test? ? self.test_url : self.live_url)
        begin
          response = parse(ssl_post(url, build_request(action, request), POST_HEADERS))
        rescue ResponseError => e
          response = parse_error(e.response)
        end

        Response.new(successful?(response), message_from(response), response,
          :test => test?,
          :authorization => authorization_from(response),
          :avs_result => {:code => response[:avs]},
          :cvv_result => response[:cvv2]
        )
      end

      def successful?(response)
        response[:transaction_approved] == SUCCESS
      end

      def authorization_from(response)
        if response[:authorization_num] && response[:transaction_tag]
          [
            response[:authorization_num],
            response[:transaction_tag],
            (response[:dollar_amount].to_f * 100).to_i
          ].join(";")
        else
          ""
        end
      end

      def money_from_authorization(auth)
        _, _, amount = auth.split(/;/, 3)
        amount.to_i # return the # of cents, no need to divide
      end

      def message_from(response)
        if(response[:faultcode] && response[:faultstring])
          response[:faultstring]
        elsif(response[:error_number] != "0")
          response[:error_description]
        else
          result = (response[:exact_message] || "")
          result << " - #{response[:bank_message]}" if response[:bank_message].present?
          result
        end
      end

      def parse_error(error)
        {
          :transaction_approved => "false",
          :error_number => error.code,
          :error_description => error.body
        }
      end

      def parse(xml)
        response = {}
        xml = REXML::Document.new(xml)

        if root = REXML::XPath.first(xml, "//TransactionResult")
          parse_elements(response, root)
        end

        response.delete_if{ |k,v| SENSITIVE_FIELDS.include?(k) }
      end

      def parse_elements(response, root)
        root.elements.to_a.each do |node|
          response[node.name.gsub(/EXact/, "Exact").underscore.to_sym] = (node.text || "").strip
        end
      end
    end
  end
end

