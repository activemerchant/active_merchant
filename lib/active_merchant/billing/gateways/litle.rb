require 'rubygems'
require 'LitleOnline'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class LitleGateway < Gateway

      TEST_URL = 'https://cert.litle.com/vap/communicator/online'
      LIVE_URL = 'https://payments.litle.com/vap/communicator/online'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.litle.com/'

      # The name of the gateway
      self.display_name = 'Litle & Co.'

      self.default_currency = 'USD'

      attr_accessor :configuration

      attr_accessor :order_id

      def initialize
        @litle = LitleOnlineRequest.new
        @configuration = Configuration.new.config
        @order_id = 'undefined'
      end

      def authorize(money, creditcard, options = {})
        toPass = createCreditCardHash(money, creditcard, options)
        ret = @litle.authorization(toPass)  # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.authorizationResponse.response == '000'),
          ret.authorizationResponse.message,
          {:litleOnlineResponse=>ret} ,
          {:authorization => ret.authorizationResponse.litleTxnId,
            :avs_result => {:code=>fraud_result(ret.authorizationResponse)['avs']},
            :cvv_result => fraud_result(ret.authorizationResponse)['cvv']
          }
          )
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret})
        end
        return resp

      end

      def purchase(money, creditcard, options = {})
        toPass = createCreditCardHash(money, creditcard, options)
        ret = @litle.sale(toPass)  # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.saleResponse.response == '000'), ret.saleResponse.message,{:litleOnlineResponse=>ret},          
            {
            :avs_result => {:code=>fraud_result(ret.saleResponse)['avs']},
            :cvv_result => fraud_result(ret.saleResponse)['cvv']
          }
          )
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret}
          )
        end
        return resp
      end

      def capture(money, authorization, options = {})
        toPass = createCaptureHash(money, authorization, options)
        ret = @litle.capture(toPass)  # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.captureResponse.response == '000'), ret.captureResponse.message,{:litleOnlineResponse=>ret})
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret})
        end
        return resp
      end

      def void(identification, options = {})
        toPass = createVoidHash(identification, options)
        ret = @litle.void(toPass)  # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.voidResponse.response == '000'), ret.voidResponse.message,{:litleOnlineResponse=>ret})
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret})
        end
        return resp
      end

      def credit(money, identification, options = {})
        toPass = createCreditHash(money, identification, options)
        ret = @litle.credit(toPass)  # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.creditResponse.response == '000'), ret.creditResponse.message,{:litleOnlineResponse=>ret})
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret})
        end
        return resp
      end

      def store(creditcard, options = {})
        toPass = createTokenHash(creditcard, options)
        ret = @litle.registerTokenRequest(toPass)  # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.registerTokenResponse.response == '801' or ret.registerTokenResponse.response == '802'), ret.registerTokenResponse.message,{:litleOnlineResponse=>ret})
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret})
        end
        return resp
      end

      private
      @@card_type = {
        'visa' => 'VI',
        'master' => 'MC',
        'american_express' => 'AX',
        'discover' => 'DI',
        'jcb' => 'DI',
        'diners_club' => 'DI'
      }

      @@avs_response_code = {
        '00' => 'Y',
        '01' => 'X',
        '02' => 'D',
        '10' => 'Z',
        '11' => 'W',
        '12' => 'A',
        '13' => 'A',
        '14' => 'P',
        '20' => 'N',
        '30' => 'S',
        '31' => 'R',
        '32' => 'U',
        '33' => 'R',
        '34' => 'I',
        '40' => 'E'
      }

      def createCreditCardHash(money, creditcard, options)
        ccType = @@card_type[creditcard.type]

        expDateYr = creditcard.year.to_s()[2..3]

        if( creditcard.month.to_s().length == 1 )
          expDateMo = '0' + creditcard.month.to_s()
        else
          expDateMo = creditcard.month.to_s()
        end

        expDate = expDateMo + expDateYr

        card_info = {
          'type' => ccType,
          'number' => creditcard.number,
          'expDate' => expDate,
          'cardValidationNum' => creditcard.verification_value
        }

        hash = createHash(money, options)
        hash['card'] = card_info
        return hash
      end

      def createCaptureHash(money, authorization, options)
        hash = createHash(money, options)
        hash['litleTxnId'] = authorization
        return hash
      end

      def createCreditHash(money, identification, options)
        hash = createHash(money, options)
        hash['litleTxnId'] = identification
        hash['orderSource'] = nil
        hash['orderId'] = nil
        return hash
      end

      def createTokenHash(creditcard, options)
        hash = createHash(0, options)
        hash['accountNumber'] = creditcard.number
        return hash
      end

      def createVoidHash(identification, options)
        hash = createHash(nil, options)
        hash['litleTxnId'] = identification
        return hash
      end

      def createHash(money, options)
        currency = options[:currency]
        if( !currency.nil? )
          merchantId = @configuration['currency_merchant_map'][currency]
        end
        if(merchantId.nil?)
          merchantId = @configuration['currency_merchant_map']['DEFAULT']
        end

        fraudCheckType = {}
        if !options[:ip].nil?
          fraudCheckType['customerIpAddress'] = options[:ip]
        end

        enhancedData = {}
        if !options[:invoice].nil?
          enhancedData['invoiceReferenceNumber'] = options[:invoice]
        end

        if !options[:description].nil?
          enhancedData['customerReference'] = options[:description]
        end

        if !options[:billing_address].nil?
          billToAddress = {
            'name' => options[:billing_address][:name],
            'companyName' => options[:billing_address][:company],
            'addressLine1' => options[:billing_address][:address1],
            'addressLine2' => options[:billing_address][:address2],
            'city' => options[:billing_address][:city],
            'state' => options[:billing_address][:state],
            'zip' => options[:billing_address][:zip],
            'country' => options[:billing_address][:country],
            'email' => options[:email],
            'phone' => options[:billing_address][:phone]
          }
        end
        if !options[:shipping_address].nil?
          shipToAddress = {
            'name' => options[:shipping_address][:name],
            'companyName' => options[:shipping_address][:company],
            'addressLine1' => options[:shipping_address][:address1],
            'addressLine2' => options[:shipping_address][:address2],
            'city' => options[:shipping_address][:city],
            'state' => options[:shipping_address][:state],
            'zip' => options[:shipping_address][:zip],
            'country' => options[:shipping_address][:country],
            'email' => options[:email],
            'phone' => options[:shipping_address][:phone]
          }
        end

        hash = {
          'billToAddress' => billToAddress,
          'shipToAddress' => shipToAddress,
          'orderId' => (options[:order_id] or @order_id),
          'customerId' => options[:customer],
          'reportGroup' => (options[:merchant] or merchantId),
          'merchantId' => merchantId,
          'orderSource' => 'ecommerce',
          'enhancedData' => enhancedData,
          'fraudCheckType' => fraudCheckType
        }

        if( !money.nil? && money.to_s.length > 0 )
          hash.merge!({'amount' => money})
        end

        return hash
      end

      def fraud_result(authorizationResponse)
        if authorizationResponse.respond_to?('fraudResult')
          fraudResult = authorizationResponse.fraudResult
          if fraudResult.respond_to?('cardValidationResult')
            cvv_to_pass = fraudResult.cardValidationResult
            if(cvv_to_pass == "")
              cvv_to_pass = "P"
            end
          end
          if fraudResult.respond_to?('avsResult')
            avs_to_pass = @@avs_response_code[fraudResult.avsResult]
          end
        end
        return {'cvv'=>cvv_to_pass, 'avs'=>avs_to_pass}
      end

    end
  end
end
