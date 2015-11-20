module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TransFirstGateway < Gateway
      self.test_url = 'https://ws.cert.transfirst.com'
      self.live_url = 'https://webservices.primerchants.com'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.transfirst.com/'
      self.display_name = 'TransFirst'

      UNUSED_FIELDS = %w(ECIValue UserId CAVVData TrackData POSInd EComInd MerchZIP MerchCustPNum MCC InstallmentNum InstallmentOf POSEntryMode POSConditionCode AuthCharInd CardCertData)

      DECLINED = 'The transaction was declined'

      ACTIONS = {
        purchase: "CCSale",
        purchase_echeck: "ACHDebit",
        refund: "CreditCardAutoRefundorVoid",
        refund_echeck: "ACHVoidTransaction",
        void: "CreditCardAutoRefundorVoid",
      }

      ENDPOINTS = {
        purchase: "creditcard.asmx",
        purchase_echeck: "checkverifyws/checkverifyws.asmx",
        refund: "creditcard.asmx",
        refund_echeck: "checkverifyws/checkverifyws.asmx",
        void: "creditcard.asmx"
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment, options = {})
        post = {}

        add_amount(post, money)
        add_invoice(post, options)
        add_payment(post, payment)
        add_address(post, options)

        commit((payment.is_a?(Check) ? :purchase_echeck : :purchase), post)
      end

      def refund(money, authorization, options={})
        post = {}
        transaction_id, payment_type = split_authorization(authorization)
        add_amount(post, money)
        add_invoice(post, options)
        add_pair(post, :TransID, transaction_id)
        commit((payment_type == "check" ? :refund_echeck : :refund), post)
      end

      def void(authorization, options={})
        post = {}
        transaction_id, _ = split_authorization(authorization)
        add_pair(post, :TransID, transaction_id)

        commit(:void, post)
      end

      private

      def add_amount(post, money)
        add_pair(post, :Amount, amount(money), required: true)
      end

      def add_address(post, options)
        address = options[:billing_address] || options[:address]

        if address
          add_pair(post, :Address, address[:address1])
          add_pair(post, :ZipCode, address[:zip])
        end
      end

      def add_invoice(post, options)
        add_pair(post, :RefID, options[:order_id], required: true)
        add_pair(post, :SECCCode, options[:invoice], required: true)
        add_pair(post, :PONumber, options[:invoice], required: true)
        add_pair(post, :SaleTaxAmount, amount(options[:tax] || 0))
        add_pair(post, :PaymentDesc, options[:description], required: true)
        add_pair(post, :TaxIndicator, 0)
        add_pair(post, :CompanyName, options[:company_name] || "", required: true)
      end

      def add_payment(post, payment)
        if payment.is_a?(Check)
          add_echeck(post, payment)
        else
          add_credit_card(post, payment)
        end
      end

      def add_credit_card(post, payment)
        add_pair(post, :CardHolderName, payment.name, required: true)
        add_pair(post, :CardNumber, payment.number, required: true)
        add_pair(post, :Expiration, expdate(payment), required: true)
        add_pair(post, :CVV2, payment.verification_value)
      end

      def add_echeck(post, payment)
        add_pair(post, :TransRoute, payment.routing_number, required: true)
        add_pair(post, :BankAccountNo, payment.account_number, required: true)
        add_pair(post, :BankAccountType, payment.account_type.capitalize, required: true)
        add_pair(post, :CheckType, payment.account_holder_type.capitalize, required: true)
        add_pair(post, :Name, payment.name, required: true)
        add_pair(post, :ProcessDate, Time.now.strftime("%m%d%y"), required: true)
        add_pair(post, :Description, "", required: true)
      end

      def add_unused_fields(post)
        UNUSED_FIELDS.each do |f|
          post[f] = ""
        end
      end

      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)

        "#{month}#{year}"
      end

      def parse(data)
        response = {}

        xml = REXML::Document.new(data)
        root = REXML::XPath.first(xml, "*")

        if root.nil?
          response[:message] = data.to_s.strip
        else
          root.elements.to_a.each do |node|
            response[node.name.underscore.to_sym] = node.text
          end
        end

        response
      end

      def commit(action, params)
        response = parse(ssl_post(url(action), post_data(params)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          :test => test?,
          :authorization => authorization_from(response),
          :avs_result => { :code => response[:avs_code] },
          :cvv_result => response[:cvv2_code]
        )
      end

      def authorization_from(response)
        if response[:status] == "APPROVED"
          "#{response[:trans_id]}|check"
        else
          "#{response[:trans_id]}|creditcard"
        end
      end

      def success_from(response)
        case response[:status]
        when "Authorized"
          true
        when "Voided"
          true
        when "APPROVED"
          true
        when "VOIDED"
          true
        else
          false
        end
      end

      def message_from(response)
        case response[:message]
        when 'Call Voice Center'
          DECLINED
        else
          response[:message]
        end
      end

      def post_data(params = {})
        add_unused_fields(params)
        params[:MerchantID] = @options[:login]
        params[:RegKey] = @options[:password]

        request = params.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end

      def add_pair(post, key, value, options = {})
        post[key] = value if !value.blank? || options[:required]
      end

      def url(action)
        base_url = test? ? test_url : live_url
        "#{base_url}/#{ENDPOINTS[action]}/#{ACTIONS[action]}"
      end

      def split_authorization(authorization)
        authorization.split("|")
      end
    end
  end
end

