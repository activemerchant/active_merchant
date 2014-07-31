module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information on the Iridium Gateway please download the
    # documentation from their Merchant Management System.
    #
    # The login and password are not the username and password you use to
    # login to the Iridium Merchant Management System. Instead, you will
    # use the API username and password you were issued separately.
    class IridiumGateway < Gateway
      self.live_url = self.test_url = 'https://gw1.iridiumcorp.net/'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['GB', 'ES']
      self.default_currency = 'EUR'
      self.money_format = :cents

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :maestro, :jcb, :solo, :diners_club]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.iridiumcorp.co.uk/'

      # The name of the gateway
      self.display_name = 'Iridium'

      CURRENCY_CODES = {
        "AED" => '784',
        "AFN" => '971',
        "ALL" => '008',
        "AMD" => '051',
        "ANG" => '532',
        "AOA" => '973',
        "ARS" => '032',
        "AUD" => '036',
        "AWG" => '533',
        "AZN" => '944',
        "BAM" => '977',
        "BBD" => '052',
        "BDT" => '050',
        "BGN" => '975',
        "BHD" => '048',
        "BIF" => '108',
        "BMD" => '060',
        "BND" => '096',
        "BOB" => '068',
        "BOV" => '984',
        "BRL" => '986',
        "BSD" => '044',
        "BTN" => '064',
        "BWP" => '072',
        "BYR" => '974',
        "BZD" => '084',
        "CAD" => '124',
        "CDF" => '976',
        "CHE" => '947',
        "CHF" => '756',
        "CHW" => '948',
        "CLF" => '990',
        "CLP" => '152',
        "CNY" => '156',
        "COP" => '170',
        "COU" => '970',
        "CRC" => '188',
        "CUP" => '192',
        "CVE" => '132',
        "CYP" => '196',
        "CZK" => '203',
        "DJF" => '262',
        "DKK" => '208',
        "DOP" => '214',
        "DZD" => '012',
        "EEK" => '233',
        "EGP" => '818',
        "ERN" => '232',
        "ETB" => '230',
        "EUR" => '978',
        "FJD" => '242',
        "FKP" => '238',
        "GBP" => '826',
        "GEL" => '981',
        "GHS" => '288',
        "GIP" => '292',
        "GMD" => '270',
        "GNF" => '324',
        "GTQ" => '320',
        "GYD" => '328',
        "HKD" => '344',
        "HNL" => '340',
        "HRK" => '191',
        "HTG" => '332',
        "HUF" => '348',
        "IDR" => '360',
        "ILS" => '376',
        "INR" => '356',
        "IQD" => '368',
        "IRR" => '364',
        "ISK" => '352',
        "JMD" => '388',
        "JOD" => '400',
        "JPY" => '392',
        "KES" => '404',
        "KGS" => '417',
        "KHR" => '116',
        "KMF" => '174',
        "KPW" => '408',
        "KRW" => '410',
        "KWD" => '414',
        "KYD" => '136',
        "KZT" => '398',
        "LAK" => '418',
        "LBP" => '422',
        "LKR" => '144',
        "LRD" => '430',
        "LSL" => '426',
        "LTL" => '440',
        "LVL" => '428',
        "LYD" => '434',
        "MAD" => '504',
        "MDL" => '498',
        "MGA" => '969',
        "MKD" => '807',
        "MMK" => '104',
        "MNT" => '496',
        "MOP" => '446',
        "MRO" => '478',
        "MTL" => '470',
        "MUR" => '480',
        "MVR" => '462',
        "MWK" => '454',
        "MXN" => '484',
        "MXV" => '979',
        "MYR" => '458',
        "MZN" => '943',
        "NAD" => '516',
        "NGN" => '566',
        "NIO" => '558',
        "NOK" => '578',
        "NPR" => '524',
        "NZD" => '554',
        "OMR" => '512',
        "PAB" => '590',
        "PEN" => '604',
        "PGK" => '598',
        "PHP" => '608',
        "PKR" => '586',
        "PLN" => '985',
        "PYG" => '600',
        "QAR" => '634',
        "ROL" => '642',
        "RON" => '946',
        "RSD" => '941',
        "RUB" => '643',
        "RWF" => '646',
        "SAR" => '682',
        "SBD" => '090',
        "SCR" => '690',
        "SDG" => '938',
        "SEK" => '752',
        "SGD" => '702',
        "SHP" => '654',
        "SKK" => '703',
        "SLL" => '694',
        "SOS" => '706',
        "SRD" => '968',
        "STD" => '678',
        "SYP" => '760',
        "SZL" => '748',
        "THB" => '764',
        "TJS" => '972',
        "TMM" => '795',
        "TND" => '788',
        "TOP" => '776',
        "TRY" => '949',
        "TTD" => '780',
        "TWD" => '901',
        "TZS" => '834',
        "UAH" => '980',
        "UGX" => '800',
        "USD" => '840',
        "USN" => '997',
        "USS" => '998',
        "UYU" => '858',
        "UZS" => '860',
        "VEB" => '862',
        "VND" => '704',
        "VUV" => '548',
        "WST" => '882',
        "XAF" => '950',
        "XAG" => '961',
        "XAU" => '959',
        "XBA" => '955',
        "XBB" => '956',
        "XBC" => '957',
        "XBD" => '958',
        "XCD" => '951',
        "XDR" => '960',
        "XOF" => '952',
        "XPD" => '964',
        "XPF" => '953',
        "XPT" => '962',
        "XTS" => '963',
        "XXX" => '999',
        "YER" => '886',
        "ZAR" => '710',
        "ZMK" => '894',
        "ZWD" => '716',
      }

      AVS_CODE = {
        "PASSED" => "Y",
        "FAILED" => "N",
        "PARTIAL" => "X",
        "NOT_CHECKED" => "X",
        "UNKNOWN" => "X"
      }

      CVV_CODE = {
        "PASSED" => "M",
        "FAILED" => "N",
        "PARTIAL" => "I",
        "NOT_CHECKED" => "P",
        "UNKNOWN" => "U"
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, payment_source, options = {})
        setup_address_hash(options)

        if payment_source.respond_to?(:number)
          commit(build_purchase_request('PREAUTH', money, payment_source, options), options)
        else
          commit(build_reference_request('PREAUTH', money, payment_source, options), options)
        end
      end

      def purchase(money, payment_source, options = {})
        setup_address_hash(options)

        if payment_source.respond_to?(:number)
          commit(build_purchase_request('SALE', money, payment_source, options), options)
        else
          commit(build_reference_request('SALE', money, payment_source, options), options)
        end
      end

      def capture(money, authorization, options = {})
        commit(build_reference_request('COLLECTION', money, authorization, options), options)
      end

      def credit(money, authorization, options={})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      def refund(money, authorization, options={})
        commit(build_reference_request('REFUND', money, authorization, options), options)
      end

      def void(authorization, options={})
        commit(build_reference_request('VOID', nil, authorization, options), options)
      end

      private

      def build_purchase_request(type, money, creditcard, options)
        options.merge!(:action => 'CardDetailsTransaction')
        build_request(options) do |xml|
          add_purchase_data(xml, type, money, options)
          add_creditcard(xml, creditcard)
          add_customerdetails(xml, creditcard, options[:billing_address], options)
        end
      end

      def build_reference_request(type, money, authorization, options)
        options.merge!(:action => 'CrossReferenceTransaction')
        order_id, cross_reference, _ = authorization.split(";")
        build_request(options) do |xml|
          if money
            details = {'CurrencyCode' => currency_code(options[:currency] || default_currency), 'Amount' => amount(money)}
          else
            details = {'CurrencyCode' => currency_code(default_currency), 'Amount' => '0'}
          end
          xml.tag! 'TransactionDetails', details do
            xml.tag! 'MessageDetails', {'TransactionType' => type, 'CrossReference' => cross_reference}
            xml.tag! 'OrderID', (options[:order_id] || order_id)
          end
        end
      end

      def build_request(options)
        requires!(options, :action)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
        xml.tag! 'soap:Envelope', { 'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
                                    'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                                    'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema'} do
          xml.tag! 'soap:Body' do
            xml.tag! options[:action], {'xmlns' => "https://www.thepaymentgateway.net/"} do
              xml.tag! 'PaymentMessage' do
                add_merchant_data(xml, options)
                yield(xml)
              end
            end
          end
        end
        xml.target!
      end

      def setup_address_hash(options)
        options[:billing_address] = options[:billing_address] || options[:address] || {}
        options[:shipping_address] = options[:shipping_address] || {}
      end

      def add_purchase_data(xml, type, money, options)
        requires!(options, :order_id)
        xml.tag! 'TransactionDetails', {'Amount' => amount(money), 'CurrencyCode' => currency_code(options[:currency] || currency(money))} do
          xml.tag! 'MessageDetails', {'TransactionType' => type}
          xml.tag! 'OrderID', options[:order_id]
          xml.tag! 'TransactionControl' do
            xml.tag! 'ThreeDSecureOverridePolicy', 'FALSE'
            xml.tag! 'EchoAVSCheckResult', 'TRUE'
            xml.tag! 'EchoCV2CheckResult', 'TRUE'
          end
        end
      end

      def add_customerdetails(xml, creditcard, address, options, shipTo = false)
        xml.tag! 'CustomerDetails' do
          if address
            unless address[:country].blank?
              country_code = Country.find(address[:country]).code(:numeric)
            end
            xml.tag! 'BillingAddress' do
              xml.tag! 'Address1', address[:address1]
              xml.tag! 'Address2', address[:address2]
              xml.tag! 'City', address[:city]
              xml.tag! 'State', address[:state]
              xml.tag! 'PostCode', address[:zip]
              xml.tag! 'CountryCode', country_code if country_code
            end
            xml.tag! 'PhoneNumber', address[:phone]
          end

          xml.tag! 'EmailAddress', options[:email]
          xml.tag! 'CustomerIPAddress', options[:ip] || "127.0.0.1"
        end
      end

      def add_creditcard(xml, creditcard)
        xml.tag! 'CardDetails' do
          xml.tag! 'CardName', creditcard.name
          xml.tag! 'CV2', creditcard.verification_value if creditcard.verification_value
          xml.tag! 'CardNumber', creditcard.number
          xml.tag! 'ExpiryDate', { 'Month' => creditcard.month.to_s.rjust(2, "0"), 'Year' => creditcard.year.to_s[/\d\d$/] }
        end
      end

      def add_merchant_data(xml, options)
        xml.tag! 'MerchantAuthentication', {"MerchantID" => @options[:login], "Password" => @options[:password]}
      end

      def commit(request, options)
        requires!(options, :action)
        response = parse(ssl_post(test? ? self.test_url : self.live_url, request,
                              {"SOAPAction" => "https://www.thepaymentgateway.net/#{options[:action]}",
                               "Content-Type" => "text/xml; charset=utf-8" }))

        success = response[:transaction_result][:status_code] == "0"
        message = response[:transaction_result][:message]
        authorization = success ? [ options[:order_id], response[:transaction_output_data][:cross_reference], response[:transaction_output_data][:auth_code] ].compact.join(";") : nil

        Response.new(success, message, response,
          :test => test?,
          :authorization => authorization,
          :avs_result => {
            :street_match => AVS_CODE[ response[:transaction_output_data][:address_numeric_check_result] ],
            :postal_match => AVS_CODE[ response[:transaction_output_data][:post_code_check_result] ],
          },
          :cvv_result => CVV_CODE[ response[:transaction_output_data][:cv2_check_result] ]
        )
      end

      def parse(xml)
        reply = {}
        xml = REXML::Document.new(xml)
        if (root = REXML::XPath.first(xml, "//CardDetailsTransactionResponse")) or
              (root = REXML::XPath.first(xml, "//CrossReferenceTransactionResponse"))
          root.elements.to_a.each do |node|
            case node.name
            when 'Message'
              reply[:message] = reply(node.text)
            else
              parse_element(reply, node)
            end
          end
        elsif root = REXML::XPath.first(xml, "//soap:Fault")
          parse_element(reply, root)
          reply[:message] = "#{reply[:faultcode]}: #{reply[:faultstring]}"
        end
        reply
      end

      def parse_element(reply, node)
        case node.name
        when "CrossReferenceTransactionResult"
          reply[:transaction_result] = {}
          node.attributes.each do |a,b|
            reply[:transaction_result][a.underscore.to_sym] = b
          end
          node.elements.each{|e| parse_element(reply[:transaction_result], e) } if node.has_elements?

        when "CardDetailsTransactionResult"
          reply[:transaction_result] = {}
          node.attributes.each do |a,b|
            reply[:transaction_result][a.underscore.to_sym] = b
          end
          node.elements.each{|e| parse_element(reply[:transaction_result], e) } if node.has_elements?

        when "TransactionOutputData"
          reply[:transaction_output_data] = {}
          node.attributes.each{|a,b| reply[:transaction_output_data][a.underscore.to_sym] = b }
          node.elements.each{|e| parse_element(reply[:transaction_output_data], e) } if node.has_elements?
        when "CustomVariables"
          reply[:custom_variables] = {}
          node.attributes.each{|a,b| reply[:custom_variables][a.underscore.to_sym] = b }
          node.elements.each{|e| parse_element(reply[:custom_variables], e) } if node.has_elements?
        when "GatewayEntryPoints"
          reply[:gateway_entry_points] = {}
          node.attributes.each{|a,b| reply[:gateway_entry_points][a.underscore.to_sym] = b }
          node.elements.each{|e| parse_element(reply[:gateway_entry_points], e) } if node.has_elements?
        else
          k = node.name.underscore.to_sym
          if node.has_elements?
            reply[k] = {}
            node.elements.each{|e| parse_element(reply[k], e) }
          else
            if node.has_attributes?
              reply[k] = {}
              node.attributes.each{|a,b| reply[k][a.underscore.to_sym] = b }
            else
              reply[k] = node.text
            end
          end
        end
        reply
      end

      def currency_code(currency)
        CURRENCY_CODES[currency]
      end
    end
  end
end
