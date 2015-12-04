module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    #
    # Custom gateway created for ScreeningOne's ACI payment processor.
    # It is a *very* non-standard gateway. It is intended to be a short-
    #
    # This is only a partial implementation of what the gateway is capable of
    #
    class AciStagedPaymentsGateway < Gateway
      TEST_URL = 'https://collectpay-uat.princetonecom.com/connect/namevaluepair/createCreditCardPayment1.do'
      LIVE_URL = 'https://collectpay.princetonecom.com/connect/namevaluepair/createCreditCardPayment1.do'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'https://collectpay.princetonecom.com' # doesn't work

      # The name of the gateway
      self.display_name = 'ACI Staged Payments via PrincetonECom'


      def initialize(options = {})
        requires!(options, :login, :password, :gateway_id, :payee_id)
        @options = options
        @options['businessId']           = @options.delete(:gateway_id)
        @options['billingAccountNumber'] = @options.delete(:payee_id)
        super
      end


      def authorize(money, credit_card, options = {})
        post = {}
        add_credit_card(post, credit_card)
        add_address(post, options)

        commit_authorize(money, post)
      end


      # expects the authorization to be the transaction_number instead of the authorization
      def capture(money, authorization, options = {})
        options[:confirmation_id] = authorization
        response_message = 'XML Capture file successfully submitted.'
        begin
          xml = build_capture_xml(money, options)
          success = upload_file xml
        rescue Exception => e
          response_message = "XML Capture failed: #{e.message}"
        end
        #TODO: what to build for the response? what is needed?
        response = {}
        # Return the response.
        Response.new(success, response_message, response,
                     :test => test?,
                     # :authorization => @response['authorizationCode'],
                     # :avs_code => @response['addressValidationCode'],
                     # :transaction_id => @response['transactionCode']
        )
      end


      private


      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post['accountHolderName']   = "#{options[:first_name]} #{options[:last_name]}"
          post['accountAddress1']     = address[:address1].to_s
          post['accountCity']         = address[:city].to_s
          post['accountState']        = address[:state].to_s
          post['accountPostalCode']   = address[:zip].to_s
          post['accountCountryCode']  = address[:country].blank? ? 'US' : address[:country].to_s
        end
      end


      def add_credit_card(post, credit_card)
        # card details
        post['creditCardNumber'] = credit_card.number
        post['creditCardType']   = credit_card_type(credit_card)
        #TODO: sample Post data shows month as single digit "&expirationMonth=1&expirationYear=2008"
        post['expirationMonth']  = credit_card.month
        post['expirationYear']   = credit_card.year
        post['securityCode']     = credit_card.verification_value
      end


      def parse(body)
        resp = {}
        # body.split("\n").each do |li|
        body.split('|').each do |li|
          next if li.strip.blank?
          key, value = li.split("=")
          # only keep the first occurrence of a key.
          # Errors will reuse the same messageCode and messageText
          # entry multiple times. First one is likely more important.
          # It can be the "Login ID is required."
          resp[key] ||= value.to_s.strip
        end
        resp
      end


      def commit_authorize(money, parameters)
        parameters['remitAmount'] = amount(money)
        url = test? ? TEST_URL : LIVE_URL

        data = ssl_post url, post_data(parameters), {'Content-Type' => 'application/x-www-form-urlencoded'}

        response = parse(data)
        success  = response['messageCode'].to_s == '0'


        # Return the response.
        Response.new(success, response['messageText'], response,
                     :test => test?,
                     :authorization => response['authorizationCode'],
                     :avs_code => response['addressValidationCode'],
                     :transaction_id => response['transactionCode']
        )
      end


      # Return the card type as desired by the gateway
      def credit_card_type(credit_card)
        case credit_card.type
          when "visa"
            'VISA'
          when "master"
            'MC'
          when "discover"
            'DISC'
          when "american_express"
            'AMEX'
        end
      end


      def post_data(params = {})
        post = {}
        post['login']         = @options[:login]
        post['password']      = @options[:password]
        post['businessId']    = @options['businessId']
        post['billingAccountNumber'] = @options['billingAccountNumber']
        post['product']       = 'IVR'
        post['ecommerceIndicator'] = 'ECOMMERCE'
        post['requestedPaymentDate'] = DateTime.now.strftime('%Y-%m-%d')
        # combine with the other parameters and URL encode
        request = post.merge(params)
        request.to_query
      end


      def build_capture_xml(money, options)
        namespace_options = {
          "xsi:schemaLocation" => 'http://www.princetonecom.com/cpbatch/stagedbatchpaymentstaged_batch_payment_request.xsd',
          "xmlns" => 'http://www.princetonecom.com/cpbatch/stagedbatchpayment',
          "xmlns:xsi" => 'http://www.w3.org/2001/XMLSchema-instance'
        }

        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! 'staged_batch_payment_request', namespace_options do
          xml.tag! 'staged-batch-payment' do
            xml.tag! 'confirmation-number', options[:confirmation_id]
            xml.tag! 'billing-account-number', options['billingAccountNumber']
            # no pay-date given, defaults to the one in the authorization
            xml.tag! 'amount', money
          end
        end
        xml
      end

    end
  end
end

