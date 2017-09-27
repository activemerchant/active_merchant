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
        add_remembered_amount(post, authorization)
        add_tax(post, options)
        add_order_id(post, options)

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

      def add_invoice(post, money, options)
        post[:Amount] = amount(money)
        post[:CurrencyCode] = options[:currency] || currency(money)
        post[:InvoiceDetail] = options[:invoice_detail] if options[:invoice_detail]
        post[:CustomerCode] = options[:customer_code] if options[:customer_code]
        add_order_id(post, options)
        add_tax(post, options)
      end

      def add_payment_method(post, payment_method)
        post[:NameOnCard] = payment_method.name
        post[:CardNumber] = payment_method.number
        post[:CardVerificationNumber] = payment_method.verification_value
        post[:CardExpirationDate] = format(payment_method.month, :two_digits) + format(payment_method.year, :two_digits)
        post[:CardLastFourDigits] = payment_method.last_digits
        post[:MagneticData] = payment_method.track_data if payment_method.track_data
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

      def add_order_id(post, options)
        post[:InvoiceNumber] = options[:order_id]
      end

      def add_tax(post, options)
        post[:TaxAmount] = amount(options[:tax] || 0)
      end

      def add_reference(post, authorization)
        reference_number, last_four_digits = split_authorization(authorization)
        post[:ReferenceNumber] = reference_number
        post[:CardLastFourDigits] = last_four_digits
      end

      def add_remembered_amount(post, authorization)
        post[:Amount] = split_authorization(authorization).last
      end

      def commit(action, post)
        post[:MerchantId] = @options[:merchant_id]
        post[:Password] = @options[:password]
        post[:UserId] = @options[:user_id]
        post[:TransactionType] = action

        data = build_request(post)
        begin
          xml = ssl_post(self.live_url, data, headers)
          raw = parse(xml)
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
          test: test?,
          cvv_result: cvv_result_from_xml(xml),
          avs_result: avs_result_from_xml(xml)
        )
      end

      def headers
        {
          "Accept-Encoding" => "gzip,deflate",
          "Content-Type"  => "text/xml;charset=UTF-8",
          "SOAPAction"  => "http://tempuri.org/Transactional/ProcessCreditCard"
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
      <tem:ProcessCreditCard>
         <tem:request>
           #{body}
         </tem:request>
      </tem:ProcessCreditCard>
   </soapenv:Body>
</soapenv:Envelope>
        EOS
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        body = doc.xpath("//ProcessCreditCardResult")
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

      def cvv_result_from_xml(xml)
        ActiveMerchant::Billing::CVVResult.new(cvv_result_code(xml))
      end

      def avs_result_from_xml(xml)
        ActiveMerchant::Billing::AVSResult.new(code: avs_result_code(xml))
      end

      def cvv_result_code(xml)
        cvv = validation_result_element(xml, "CVV")
        return nil unless cvv
        validation_result_matches?(*validation_result_element_text(cvv.parent)) ? 'M' : 'N'
      end

      def avs_result_code(xml)
        billing_address_elem = validation_result_element(xml, "Billing Address")
        zip_code_elem = validation_result_element(xml, "Zip Code")

        return nil unless billing_address_elem && zip_code_elem

        billing_matches = avs_result_matches(billing_address_elem)
        zip_matches = avs_result_matches(zip_code_elem)

        if billing_matches && zip_matches
          'D'
        elsif !billing_matches && zip_matches
          'P'
        elsif billing_matches && !zip_matches
          'B'
        else
          'C'
        end
      end

      def avs_result_matches(elem)
        validation_result_matches?(*validation_result_element_text(elem.parent))
      end

      def validation_result_element(xml, name)
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        doc.at_xpath("//ParameterValidationResultList//ParameterValidationResult//Name[text() = '#{name}']")
      end

      def validation_result_element_text(element)
        result_text = element.elements.detect { |elem|
          elem.name == "Result"
        }.children.detect { |elem| elem.text }.text

        result_text.split(";").collect(&:strip)
      end

      def validation_result_matches?(present, match)
        present.downcase.start_with?('present') &&
          match.downcase.start_with?('match')
      end
    end
  end
end
