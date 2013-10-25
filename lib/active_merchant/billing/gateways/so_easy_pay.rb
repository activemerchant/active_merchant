module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SoEasyPayGateway < Gateway
      self.test_url = 'https://secure.soeasypay.com/gateway.asmx'
      self.live_url = 'https://secure.soeasypay.com/gateway.asmx'
      self.money_format = :cents

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US', 'CA', 'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 
      'FI', 'FR', 'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO',
      'SK', 'SI', 'ES', 'SE', 'GB', 'IS', 'NO', 'CH']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :maestro, :jcb, :solo, :diners_club]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.soeasypay.com/'

      # The name of the gateway
      self.display_name = 'SoEasyPay'

      def initialize(options = {})
        requires!(options, :login, :password)
        @website_id = options[:login]
        @password = options[:password]
        super
      end

      def authorize(money, payment_source, options = {})

        if payment_source.respond_to?(:number)
          commit(do_authorization(money, payment_source, options), options)
        else
          commit(do_reauthorization(money, payment_source, options), options)
        end
      end

      def purchase(money, payment_source, options = {})
        if payment_source.respond_to?(:number)
          commit(do_sale(money, payment_source, options), options)
        else
          commit(do_rebill(money, payment_source, options), options)
        end
      end

      def capture(money, authorization, options = {})
        commit(do_capture(money, authorization, options), options)
      end

      def credit(money, authorization, options={})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      def refund(money, authorization, options={})
        commit(do_refund(money, authorization, options), options)
      end

      def void(authorization, options={})
        commit(do_void(authorization, options), options)
      end

      private

      def do_authorization(money, card, options)
        options.merge!({:soap_action => 'AuthorizeTransaction'})
        soap = String.new(AuthorizationTemplate)
        fill_credentials(soap, options)
        fill_order_info(soap, options.merge({:amount => amount(money), :currency => (options[:currency] || currency(money))}))
        fill_cardholder(soap, card, options)
        fill_card(soap, card)
        clear_empty_fields(soap)
        return soap
      end

      def do_sale(money, card, options)
        options.merge!({:soap_action => 'SaleTransaction'})
        soap = String.new(SaleTemplate)
        fill_credentials(soap, options)
        fill_order_info(soap, options.merge({:amount => amount(money), :currency => (options[:currency] || currency(money))}))
        fill_cardholder(soap, card, options)
        fill_card(soap, card)
        clear_empty_fields(soap)
        return soap
      end

      def do_reauthorization(money, authorization, options)
        options.merge!({:soap_action => 'ReauthorizeTransaction'})
        soap = String.new(ReauthorizeTemplate)
        fill_credentials(soap, options)
        fill_order_info(soap, options.merge({:amount => amount(money), :currency => (options[:currency] || currency(money))}))
        fill_transaction_id(soap, authorization)
        clear_empty_fields(soap)
        return soap
      end

      def do_rebill(money, authorization, options)
        options.merge!({:soap_action => 'RebillTransaction'})
        soap = String.new(RebillTemplate)
        fill_credentials(soap, options)
        fill_order_info(soap, options.merge({:amount => amount(money), :currency => (options[:currency] || currency(money))}))
        fill_transaction_id(soap, authorization)
        clear_empty_fields(soap)
        return soap
      end

      def do_capture(money, authorization, options)
        options.merge!({:soap_action => 'CaptureTransaction'})
        soap = String.new(CaptureTemplate)
        fill_credentials(soap, options)
        fill_order_info(soap, options.merge({:amount => amount(money), :currency => (options[:currency] || currency(money))}))
        fill_transaction_id(soap, authorization)
        clear_empty_fields(soap)
        return soap
      end

      def do_refund(money, authorization, options)
        options.merge!({:soap_action => 'RefundTransaction'})
        soap = String.new(RefundTemplate)
        fill_credentials(soap, options)
        fill_order_info(soap, options.merge({:amount => amount(money), :currency => (options[:currency] || currency(money))}))
        fill_transaction_id(soap, authorization)
        clear_empty_fields(soap)
        return soap
      end

      def do_void(authorization, options)
        options.merge!({:soap_action => 'CancelTransaction'})
        soap = String.new(VoidTemplate)
        fill_credentials(soap, options)
        fill_transaction_id(soap, authorization)
        clear_empty_fields(soap)
        return soap
      end

      # methods for filling fields in SOAP string - we do this by simple string
      # replacement - template strings have fields embedded as ${field}
      # in the end we clear unused fields with clear_empty_fields method
      
      def fill_credentials(soap, options)
        soap['${websiteID}'] = @website_id.to_s
        soap['${password}'] = @password.to_s
      end

      def fill_cardholder(soap, card, options)
        ch_info = options[:billing_address] || options[:address]

        soap['${customerIP}'] = options[:ip].to_s
        name = card.name || ch_info[:name]
        soap['${cardHolderName}'] = name.to_s
        address = ch_info[:address1] || ''
        address << ch_info[:address2] if ch_info[:address2]
        soap['${cardHolderAddress}'] = address.to_s
        soap['${cardHolderZipcode}'] = ch_info[:zip].to_s
        soap['${cardHolderCity}'] = ch_info[:city].to_s
        soap['${cardHolderState}'] = ch_info[:state].to_s
        soap['${cardHolderCountryCode}'] = ch_info[:country].to_s
        soap['${cardHolderPhone}'] = ch_info[:phone].to_s
        soap['${cardHolderEmail}'] = options[:email].to_s
      end

      def fill_transaction_id(soap, transaction_id)
        soap['${transactionID}'] = transaction_id.to_s
      end

      def fill_card(soap, card)
        soap['${cardNumber}'] = card.number.to_s
        soap['${cardSecurityCode}'] = card.verification_value.to_s
        soap['${cardExpireMonth}'] = card.month.to_s.rjust(2, "0")
        soap['${cardExpireYear}'] = card.year.to_s
      end

      def fill_order_info(soap, options)
        soap['${orderID}'] = options[:order_id].to_s
        soap['${orderDescription}'] = "Order #{options[:order_id]}"
        soap['${amount}'] = options[:amount].to_s
        begin                   # some templates do not accept currency at all
	        soap['${currency}'] = options[:currency].to_s
	      rescue IndexError
	      end
      end
      
      def clear_empty_fields(soap)
        soap.gsub!(/\$\{[a-zA-Z0-9]+\}/, '')
      end

      def parse(response, action)
        result = {}
        document = REXML::Document.new(response)
        response_element = document.root.get_elements("//[@xsi:type='tns:#{action}Response']").first
        response_element.elements.each do |element|
          result[element.name.underscore] = element.text
        end
        result
      end

      def commit(soap, options)
        requires!(options, :soap_action)
        soap_action = options[:soap_action]
        headers = {"SOAPAction" => "\"urn:Interface##{soap_action}\"",
                   "Content-Type" => "text/xml; charset=utf-8"}
        response_string = ssl_post(test? ? self.test_url : self.live_url, soap, headers)
        response = parse(response_string, soap_action)
        return Response.new(response['errorcode'] == '000',
                            response['errormessage'],
                            response,
                            :test => test?,
                            :authorization => response['transaction_id'])
      end
      
      # SOAP template strings for various types of transactions
      AuthorizationTemplate = '<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <tns:AuthorizeTransaction>
      <AuthorizeTransactionRequest href="#id1" />
    </tns:AuthorizeTransaction>
    <tns:AuthorizeTransactionRequest id="id1" xsi:type="tns:AuthorizeTransactionRequest">
      <websiteID xsi:type="xsd:string">${websiteID}</websiteID>
      <password xsi:type="xsd:string">${password}</password>
      <orderID xsi:type="xsd:string">${orderID}</orderID>
      <orderDescription xsi:type="xsd:string">${orderDescription}</orderDescription>
      <customerIP xsi:type="xsd:string">${customerIP}</customerIP>
      <amount xsi:type="xsd:string">${amount}</amount>
      <orderAmount xsi:type="xsd:string">${orderAmount}</orderAmount>
      <currency xsi:type="xsd:string">${currency}</currency>
      <cardHolderName xsi:type="xsd:string">${cardHolderName}</cardHolderName>
      <cardHolderAddress xsi:type="xsd:string">${cardHolderAddress}</cardHolderAddress>
      <cardHolderZipcode xsi:type="xsd:string">${cardHolderZipcode}</cardHolderZipcode>
      <cardHolderCity xsi:type="xsd:string">${cardHolderCity}</cardHolderCity>
      <cardHolderState xsi:type="xsd:string">${cardHolderState}</cardHolderState>
      <cardHolderCountryCode xsi:type="xsd:string">${cardHolderCountryCode}</cardHolderCountryCode>
      <cardHolderPhone xsi:type="xsd:string">${cardHolderPhone}</cardHolderPhone>
      <cardHolderEmail xsi:type="xsd:string">${cardHolderEmail}</cardHolderEmail>
      <cardNumber xsi:type="xsd:string">${cardNumber}</cardNumber>
      <cardSecurityCode xsi:type="xsd:string">${cardSecurityCode}</cardSecurityCode>
      <cardIssueNumber xsi:type="xsd:string">${cardIssueNumber}</cardIssueNumber>
      <cardStartMonth xsi:type="xsd:string">${cardStartMonth}</cardStartMonth>
      <cardStartYear xsi:type="xsd:string">${cardStartYear}</cardStartYear>
      <cardExpireMonth xsi:type="xsd:string">${cardExpireMonth}</cardExpireMonth>
      <cardExpireYear xsi:type="xsd:string">${cardExpireYear}</cardExpireYear>
      <AVSPolicy xsi:type="xsd:string">${AVSPolicy}</AVSPolicy>
      <FSPolicy xsi:type="xsd:string">${FSPolicy}</FSPolicy>
      <Secure3DAcsMessage xsi:type="xsd:string">${Secure3DAcsMessage}</Secure3DAcsMessage>
      <userVar1 xsi:type="xsd:string">${userVar1}</userVar1>
      <userVar2 xsi:type="xsd:string">${userVar2}</userVar2>
      <userVar3 xsi:type="xsd:string">${userVar3}</userVar3>
      <userVar4 xsi:type="xsd:string">${userVar4}</userVar4>
    </tns:AuthorizeTransactionRequest>
  </soap:Body>
</soap:Envelope>'

      SaleTemplate = '<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <tns:SaleTransaction>
      <SaleTransactionRequest href="#id1" />
    </tns:SaleTransaction>
    <tns:SaleTransactionRequest id="id1" xsi:type="tns:SaleTransactionRequest">
      <websiteID xsi:type="xsd:string">${websiteID}</websiteID>
      <password xsi:type="xsd:string">${password}</password>
      <orderID xsi:type="xsd:string">${orderID}</orderID>
      <orderDescription xsi:type="xsd:string">${orderDescription}</orderDescription>
      <customerIP xsi:type="xsd:string">${customerIP}</customerIP>
      <amount xsi:type="xsd:string">${amount}</amount>
      <orderAmount xsi:type="xsd:string">${orderAmount}</orderAmount>
      <currency xsi:type="xsd:string">${currency}</currency>
      <cardHolderName xsi:type="xsd:string">${cardHolderName}</cardHolderName>
      <cardHolderAddress xsi:type="xsd:string">${cardHolderAddress}</cardHolderAddress>
      <cardHolderZipcode xsi:type="xsd:string">${cardHolderZipcode}</cardHolderZipcode>
      <cardHolderCity xsi:type="xsd:string">${cardHolderCity}</cardHolderCity>
      <cardHolderState xsi:type="xsd:string">${cardHolderState}</cardHolderState>
      <cardHolderCountryCode xsi:type="xsd:string">${cardHolderCountryCode}</cardHolderCountryCode>
      <cardHolderPhone xsi:type="xsd:string">${cardHolderPhone}</cardHolderPhone>
      <cardHolderEmail xsi:type="xsd:string">${cardHolderEmail}</cardHolderEmail>
      <cardNumber xsi:type="xsd:string">${cardNumber}</cardNumber>
      <cardSecurityCode xsi:type="xsd:string">${cardSecurityCode}</cardSecurityCode>
      <cardIssueNumber xsi:type="xsd:string">${cardIssueNumber}</cardIssueNumber>
      <cardStartMonth xsi:type="xsd:string">${cardStartMonth}</cardStartMonth>
      <cardStartYear xsi:type="xsd:string">${cardStartYear}</cardStartYear>
      <cardExpireMonth xsi:type="xsd:string">${cardExpireMonth}</cardExpireMonth>
      <cardExpireYear xsi:type="xsd:string">${cardExpireYear}</cardExpireYear>
      <AVSPolicy xsi:type="xsd:string">${AVSPolicy}</AVSPolicy>
      <FSPolicy xsi:type="xsd:string">${FSPolicy}</FSPolicy>
      <Secure3DAcsMessage xsi:type="xsd:string">${Secure3DAcsMessage}</Secure3DAcsMessage>
      <userVar1 xsi:type="xsd:string">${userVar1}</userVar1>
      <userVar2 xsi:type="xsd:string">${userVar2}</userVar2>
      <userVar3 xsi:type="xsd:string">${userVar3}</userVar3>
      <userVar4 xsi:type="xsd:string">${userVar4}</userVar4>
    </tns:SaleTransactionRequest>
  </soap:Body>
</soap:Envelope>'

      ReauthorizeTemplate = '<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <tns:ReauthorizeTransaction>
      <ReauthorizeTransactionRequest href="#id1" />
    </tns:ReauthorizeTransaction>
    <tns:ReauthorizeTransactionRequest id="id1" xsi:type="tns:ReauthorizeTransactionRequest">
      <websiteID xsi:type="xsd:string">${websiteID}</websiteID>
      <password xsi:type="xsd:string">${password}</password>
      <transactionID xsi:type="xsd:string">${transactionID}</transactionID>
      <orderID xsi:type="xsd:string">${orderID}</orderID>
      <orderDescription xsi:type="xsd:string">${orderDescription}</orderDescription>
      <amount xsi:type="xsd:string">${amount}</amount>
      <currency xsi:type="xsd:string">${currency}</currency>
    </tns:ReauthorizeTransactionRequest>
  </soap:Body>
</soap:Envelope>'

      RebillTemplate = '<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <tns:RebillTransaction>
      <RebillTransactionRequest href="#id1" />
    </tns:RebillTransaction>
    <tns:RebillTransactionRequest id="id1" xsi:type="tns:RebillTransactionRequest">
      <websiteID xsi:type="xsd:string">${websiteID}</websiteID>
      <password xsi:type="xsd:string">${password}</password>
      <transactionID xsi:type="xsd:string">${transactionID}</transactionID>
      <orderID xsi:type="xsd:string">${orderID}</orderID>
      <orderDescription xsi:type="xsd:string">${orderDescription}</orderDescription>
      <amount xsi:type="xsd:string">${amount}</amount>
      <currency xsi:type="xsd:string">${currency}</currency>
    </tns:RebillTransactionRequest>
  </soap:Body>
</soap:Envelope>'

      CaptureTemplate = '<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <tns:CaptureTransaction>
      <CaptureTransactionRequest href="#id1" />
    </tns:CaptureTransaction>
    <tns:CaptureTransactionRequest id="id1" xsi:type="tns:CaptureTransactionRequest">
      <websiteID xsi:type="xsd:string">${websiteID}</websiteID>
      <password xsi:type="xsd:string">${password}</password>
      <transactionID xsi:type="xsd:string">${transactionID}</transactionID>
      <orderID xsi:type="xsd:string">${orderID}</orderID>
      <orderDescription xsi:type="xsd:string">${orderDescription}</orderDescription>
      <amount xsi:type="xsd:string">${amount}</amount>
    </tns:CaptureTransactionRequest>
  </soap:Body>
</soap:Envelope>'

      RefundTemplate = '<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <tns:RefundTransaction>
      <RefundTransactionRequest href="#id1" />
    </tns:RefundTransaction>
    <tns:RefundTransactionRequest id="id1" xsi:type="tns:RefundTransactionRequest">
      <websiteID xsi:type="xsd:string">${websiteID}</websiteID>
      <password xsi:type="xsd:string">${password}</password>
      <transactionID xsi:type="xsd:string">${transactionID}</transactionID>
      <orderID xsi:type="xsd:string">${orderID}</orderID>
      <orderDescription xsi:type="xsd:string">${orderDescription}</orderDescription>
      <amount xsi:type="xsd:string">${amount}</amount>
    </tns:RefundTransactionRequest>
  </soap:Body>
</soap:Envelope>'

      VoidTemplate = '<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <tns:CancelTransaction>
      <CancelTransactionRequest href="#id1" />
    </tns:CancelTransaction>
    <tns:CancelTransactionRequest id="id1" xsi:type="tns:CancelTransactionRequest">
      <websiteID xsi:type="xsd:string">${websiteID}</websiteID>
      <password xsi:type="xsd:string">${password}</password>
      <transactionID xsi:type="xsd:string">${transactionID}</transactionID>
    </tns:CancelTransactionRequest>
  </soap:Body>
</soap:Envelope>'

    end
  end
end

