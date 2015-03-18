require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CenposGateway < Gateway
      self.display_name = "CenPOS"
      self.homepage_url = "https://www.cenpos.com/"

      self.live_url = "https://ww3.cenpos.net/6/transact.asmx"

      self.supported_countries = %w(AD AI AG AR AU AT BS BB BE BZ BM BR BN BG CA HR CY CZ DK DM EE FI FR DE GR GD GY HK HU IS IN IL IT JP LV LI LT LU MY MT MX MC MS NL PA PL PT KN LC MF VC SM SG SK SI ZA ES SR SE CH TR GB US UY)
      self.default_currency = "USD"
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      def initialize(options={})
        requires!(options, :merchant_id, :password, :user_id)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("Sale", post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("Auth", post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit("SpecialForce", post)
      end

      def void(authorization, options={})
        post = {}
        add_void_required_elements(post)
        add_reference(post, authorization)
        commit("Void", post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit("SpecialReturn", post)
      end

      def credit(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)

        commit("Credit", post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<acr1:CardNumber>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<acr1:CardVerificationNumber>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<acr:Password>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency: #{k}")}
      CURRENCY_CODES["AUD"] = "036"
      CURRENCY_CODES["CAD"] = "124"
      CURRENCY_CODES["CHF"] = "756"
      CURRENCY_CODES["CZK"] = "203"
      CURRENCY_CODES["DKK"] = "208"
      CURRENCY_CODES["EUR"] = "978"
      CURRENCY_CODES["GBP"] = "826"
      CURRENCY_CODES["HKD"] = "344"
      CURRENCY_CODES["HUF"] = "348"
      CURRENCY_CODES["IRR"] = "364"
      CURRENCY_CODES["JPY"] = "392"
      CURRENCY_CODES["LVL"] = "428"
      CURRENCY_CODES["MYR"] = "458"
      CURRENCY_CODES["NOK"] = "578"
      CURRENCY_CODES["PLN"] = "985"
      CURRENCY_CODES["SEK"] = "752"
      CURRENCY_CODES["SGD"] = "702"
      CURRENCY_CODES["USD"] = "840"
      CURRENCY_CODES["ZAR"] = "710"

      def add_invoice(post, money, options)
        post[:Amount] = amount(money)
        post[:CurrencyCode] = CURRENCY_CODES[options[:currency] || currency(money)]
        post[:TaxAmount] = amount(options[:tax])
        post[:InvoiceNumber] = options[:order_id]
        post[:InvoiceDetail] = options[:description]
      end

      def add_payment_method(post, payment_method)
        post[:NameOnCard] = payment_method.name
        post[:CardNumber] = payment_method.number
        post[:CardVerificationNumber] = payment_method.verification_value
        post[:CardExpirationDate] = format(payment_method.month, :two_digits) + format(payment_method.year, :two_digits)
        post[:CardLastFourDigits] = payment_method.last_digits
        post[:MagneticData] = payment_method.track_data
      end

      def add_customer_data(post, options)
        if(billing_address = (options[:billing_address] || options[:address]))
          post[:CustomerEmailAddress] = billing_address[:email]
          post[:CustomerPhone] = billing_address[:phone]
          post[:CustomerBillingAddress] = billing_address[:address1]
          post[:CustomerCity] = billing_address[:city]
          post[:CustomerState] = billing_address[:state]
          post[:CustomerZipCode] = billing_address[:zip]
        end
      end

      def add_void_required_elements(post)
        post[:GeoLocationInformation] = nil
        post[:IMEI] = nil
      end

      def add_reference(post, authorization)
        reference_number, last_four_digits, original_amount = split_authorization(authorization)
        post[:ReferenceNumber] = reference_number
        post[:CardLastFourDigits] = last_four_digits
        post[:Amount] = original_amount
      end

      def commit(action, post)
        post[:MerchantId] = @options[:merchant_id]
        post[:Password] = @options[:password]
        post[:UserId] = @options[:user_id]
        post[:TransactionType] = action

        data = build_request(post)
        begin
          raw = parse(ssl_post(self.live_url, data, headers))
        rescue ActiveMerchant::ResponseError => e
          if(e.response.code == "500" && e.response.body.start_with?("<s:Envelope"))
            raw = {
              message: "See transcript for detailed error description."
            }
          else
            raise
          end
        end

        succeeded = success_from(raw[:result])
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          authorization: authorization_from(post, raw),
          error_code: error_code_from(succeeded, raw),
          test: test?
        )
      end

      def headers
        {
          "Accept-Encoding" => "gzip,deflate",
          "Content-Type"  => "text/xml;charset=UTF-8",
          "SOAPAction"  => "http://tempuri.org/Transactional/ProcessCard"
        }
      end

      def build_request(post)
        xml = Builder::XmlMarkup.new :indent => 8
        xml.tag!("acr:MerchantId", post.delete(:MerchantId))
        xml.tag!("acr:Password", post.delete(:Password))
        xml.tag!("acr:UserId", post.delete(:UserId))
        post.sort.each do |field, value|
          xml.tag!("acr1:#{field}", value)
        end
        envelope(xml.target!)
      end

      def envelope(body)
        <<-EOS
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/" xmlns:acr="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.Common" xmlns:acr1="http://schemas.datacontract.org/2004/07/Acriter.ABI.CenPOS.EPayment.VirtualTerminal.v6.Common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<soapenv:Header/>
   <soapenv:Body>
      <tem:ProcessCard>
         <tem:request>
           #{body}
         </tem:request>
      </tem:ProcessCard>
   </soapenv:Body>
</soapenv:Envelope>
        EOS
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        body = doc.xpath("//ProcessCardResult")
        body.children.each do |node|
          if (node.elements.size == 0)
            response[node.name.underscore.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name.underscore}_#{childnode.name.underscore}"
              response[name.to_sym] = childnode.text
            end
          end
        end unless doc.root.nil?

        response
      end

      def success_from(response)
        response == "0"
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response[:message] || "Unable to read error message"
        end
      end

      STANDARD_ERROR_CODE_MAPPING = {
        "211" => STANDARD_ERROR_CODE[:invalid_number],
        "252" => STANDARD_ERROR_CODE[:invalid_expiry_date],
        "257" => STANDARD_ERROR_CODE[:invalid_cvc],
        "333" => STANDARD_ERROR_CODE[:expired_card],
        "1" => STANDARD_ERROR_CODE[:card_declined],
        "99" => STANDARD_ERROR_CODE[:processing_error],
      }

      def authorization_from(request, response)
        [ response[:reference_number], request[:CardLastFourDigits], request[:Amount] ].join("|")
      end

      def split_authorization(authorization)
        reference_number, last_four_digits, original_amount = authorization.split("|")
        [reference_number, last_four_digits, original_amount]
      end

      def error_code_from(succeeded, response)
        succeeded ? nil : STANDARD_ERROR_CODE_MAPPING[response[:result]]
      end
    end
  end
end
