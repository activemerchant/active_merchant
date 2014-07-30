module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    HPCI_CONST = {
        #Baseline API Parameters
        :PXYPARAM_PXY_TRANSACTION_CUSISO => 'pxyTransaction.txnCurISO',
        :PXYPARAM_PXY_TRANSACTION_AMOUNT => 'pxyTransaction.txnAmount',
        :PXYPARAM_PXY_TRANSACTION_PROCESSOR_REFID => 'pxyTransaction.processorRefId',

        :PXYPARAM_PXY_CC_CARDTYPE => 'pxyCreditCard.cardType',
        :PXYPARAM_PXY_CC_CVV => 'pxyCreditCard.cardCodeVerification',

        :PXYPARAM_PXY_ORDER_TOTALAMT => 'pxyOrder.totalAmount',
        :PXYPARAM_PXY_ORDER_SHIPPINGAMT => 'pxyOrder.shippingAmount',

        :PXYRESP_CALL_STATUS_SUCCESS => 'success',
    }

    class HostedpciGateway < Gateway

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US', 'CA', 'GB', 'AU']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express,
                                  :discover, :diners_club, :jcb,
                                  :switch, :solo, :dankort,
                                  :maestro, :forbrugsforeningen, :laser]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.hostedpci.com/'

      # The name of the gateway
      self.display_name = 'HostedPCI'

      # Set the default currency
      self.default_currency = 'USD'

      def initialize(options = {})
        requires!(options, :login, :password, :hpci_api_host)
        @host = options[:hpci_api_host]
        @options = options
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_api_info(post, options, money)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        ##add the transaction amount
        post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_AMOUNT]] = amount(money)
        post[HPCI_CONST[:PXYPARAM_PXY_ORDER_TOTALAMT]] = amount(money)

        commit('authonly', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = { } #empty hash for post parameter
        add_api_info(post, options, money)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        ##add the transaction amount
        post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_AMOUNT]] = amount(money)
        post[HPCI_CONST[:PXYPARAM_PXY_ORDER_TOTALAMT]] = amount(money)

        commit('sale', money, post)
      end

      def capture(money, authorization, options = {})
        post = { } #empty hash for post parameter
        add_invoice(post, options)
        add_api_info(post, options, money)

        ##add the transaction amount
        post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_AMOUNT]] = amount(money)
        post[HPCI_CONST[:PXYPARAM_PXY_ORDER_TOTALAMT]] = amount(money)

        ##add the authorization ID
        post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_PROCESSOR_REFID]] = authorization

        commit('capture', money, post)
      end

      def void(authorization, options = {})
        post = { } #empty hash for post parameter
        add_api_info(post, options, nil)

        ##add the authorization ID to void
        post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_PROCESSOR_REFID]] = authorization

        commit('void', nil, post)
      end

      def credit(money, authorization, options = {})
        post = { } #empty hash for post parameter
        add_invoice(post, options)
        add_api_info(post, options, money)

        ##add the transaction amount
        post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_AMOUNT]] = amount(money)
        post[HPCI_CONST[:PXYPARAM_PXY_ORDER_TOTALAMT]] = amount(money)

        ##add the authorization ID to credit
        post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_PROCESSOR_REFID]] = authorization

        commit('credit', money, post)
      end

      private

      def add_api_info(post, options, money)
        ## set basic API parameters
        post['apiVersion'] = '1.0.1'
        post['apiType'] = 'pxyhpci'
        post['userName'] = @options[:login]
        post['userPassKey'] = @options[:password]

        ## set currency parameter, need access to money
        if !options[:currency].blank?
          post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_CUSISO]] = options[:currency]
        elsif !currency(money).blank?
          post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_CUSISO]] = currency(money)
        else
          post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_CUSISO]] = default_currency
        end
      end ##END: add_api_info

      def add_customer_data(post, options)
        if options.has_key? :email
          post['pxyCustomerInfo.email'] = options[:email]
        end

        if options.has_key? :customer
          post['pxyCustomerInfo.customerId'] = options[:customer]
        end

        if options.has_key? :ip
          post['pxyCustomerInfo.customerIP'] = options[:ip]
        end
      end ##END: add_customer_data

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post['pxyCustomerInfo.billingLocation.firstName'] = address[:name].to_s.split[0] if !address[:name].to_s.split[0].blank?
          post['pxyCustomerInfo.billingLocation.lastName']  = address[:name].to_s.split[1] if !address[:name].to_s.split[1].blank?
          post['pxyCustomerInfo.billingLocation.address']   = address[:address1].to_s
          post['pxyCustomerInfo.billingLocation.zipCode']   = address[:zip].to_s
          post['pxyCustomerInfo.billingLocation.city']      = address[:city].to_s
          post['pxyCustomerInfo.billingLocation.country']   = address[:country].to_s
          post['pxyCustomerInfo.billingLocation.state']     = address[:state].blank?  ? 'n/a' : address[:state]
        end

        if address = options[:shipping_address]
          post['pxyCustomerInfo.shippingLocation.firstName'] = address[:name].to_s.split[0] if !address[:name].to_s.split[0].blank?
          post['pxyCustomerInfo.shippingLocation.lastName']  = address[:name].to_s.split[1] if !address[:name].to_s.split[1].blank?
          post['pxyCustomerInfo.shippingLocation.address']   = address[:address1].to_s
          post['pxyCustomerInfo.shippingLocation.zipCode']   = address[:zip].to_s
          post['pxyCustomerInfo.shippingLocation.city']      = address[:city].to_s
          post['pxyCustomerInfo.shippingLocation.country']   = address[:country].to_s
          post['pxyCustomerInfo.shippingLocation.state']     = address[:state].blank?  ? 'n/a' : address[:state]
        end
      end ##END: add_address

      def add_invoice(post, options)
        if options.has_key? :order_id
          post['pxyOrder.invoiceNumber'] = options[:order_id]
          post['pxyTransaction.merchantRefId'] = "merRef:" + options[:order_id]
        end
        if options.has_key? :description
          post['pxyOrder.description']   = options[:description]
        end
      end

      def add_creditcard(post, creditcard)
        post['pxyCreditCard.creditCardNumber']   = creditcard.number
        post['pxyCreditCard.cardCodeVerification']  = creditcard.verification_value if creditcard.verification_value?
        post['pxyCreditCard.expirationMonth']   = creditcard.month.to_s
        post['pxyCreditCard.expirationYear']   = creditcard.year.to_s
        if creditcard.brand.nil? || creditcard.brand.empty?
          post[HPCI_CONST[:PXYPARAM_PXY_CC_CARDTYPE]]   = 'any'
        else
          post[HPCI_CONST[:PXYPARAM_PXY_CC_CARDTYPE]]   = creditcard.brand
        end
      end ##END: add_creditcard

      def get_message_from_response(results)
        msg = 'not set'
        if (results.nil? || results.empty? || results[:call_status] != HPCI_CONST[:PXYRESP_CALL_STATUS_SUCCESS])
          msg = 'API Call Error, check API Parameters.'

          ##add error parameters that may be present
          if (!results[:error_id].nil?)
            msg += ' Error_ID: ' + results[:error_id]
          end
          if (!results[:error_msg].nil?)
            msg += '; Error Message: ' + results[:error_msg]
          end
        else
          #basic call succesful, contruct result message
          msg = 'description: ' + results[:status_description] +
              '; status_code:' + results[:status_code] +
              '; status_name:' + results[:status_name]
        end
        msg
      end

      def commit(action, money, parameters)
        if action == 'sale'
          serviceUrl = '/iSynSApp/paymentSale.action'
        elsif action =='authonly'
          serviceUrl = '/iSynSApp/paymentAuth.action'
        elsif action == 'capture'
          serviceUrl = '/iSynSApp/paymentCapture.action'
        elsif action =='void'
          serviceUrl = '/iSynSApp/paymentVoid.action'
        elsif action == 'credit'
          serviceUrl = '/iSynSApp/paymentCredit.action'
        else
          raise Exception, 'Unsupported HPCI payment action: ' + action
        end

        #contruct the URL to the restful service
        url = @host + serviceUrl

        #perform the http post
        data = ssl_post url, post_data(action, parameters)

        ## parse response data into hash
        response = parse(data)

        message = get_message_from_response (response)

        res = Response.new(success?(response), message, response,
                           :test => false,
                           :authorization => response[:processor_refid],
                           :fraud_review => fraud_review?(response),
        #:avs_result => { :code => response[:avs_result_code] },
        #:cvv_result => response[:card_code]
        )

        res
      end ##END: commit payment operation

      def success?(response)
        (response[:call_status] == HPCI_CONST[:PXYRESP_CALL_STATUS_SUCCESS]) &&
            (response[:payment_status] == 'approved')
      end ##END: success?

      def fraud_review?(response)
        return false
      end ##END: fraud_review?


      def parse(body)
        responseHash = { } ## empty response hash
        results = { } ## move values from hash to results

        if (!body.nil? && !body.empty?)
          responseHash = CGI.parse(body)
        end

        if !responseHash.empty?
          put_in_map results, :call_status, responseHash['status']
          put_in_map results, :error_id, responseHash['errId']
          put_in_map results, :error_msg, responseHash['errMsg']
          put_in_map results, :payment_status, responseHash['pxyResponse.responseStatus']
          put_in_map results, :status_code, responseHash['pxyResponse.responseStatus.code']
          put_in_map results, :status_name, responseHash['pxyResponse.responseStatus.name']
          put_in_map results, :status_description, responseHash['pxyResponse.responseStatus.description']
          put_in_map results, :processor_refid, responseHash['pxyResponse.processorRefId']
          put_in_map results, :processor_type, responseHash['pxyResponse.processorType']
          put_in_map results, :processor_native_response, responseHash['pxyResponse.fullNativeResp']
          put_in_map results, :processor_native_fraud_response, responseHash['pxyResponse.fullFraudNativeResp']
          put_in_map results, :avs1_response, responseHash['pxyResponse.responseAVS1']
          put_in_map results, :avs2_response, responseHash['pxyResponse.responseAVS2']
          put_in_map results, :avs3_response, responseHash['pxyResponse.responseAVS3']
          put_in_map results, :avs4_response, responseHash['pxyResponse.responseAVS2']
          put_in_map results, :cvv1_response, responseHash['pxyResponse.responseCVV1']
          put_in_map results, :cvv2_response, responseHash['pxyResponse.responseCVV2']
        end

        results
      end ##END: parse

      #utility to pass values between result maps
      def put_in_map (to, idx, from)
        if !from.nil? && !from.empty?
          to[idx] = from[0] #get the first element of the array
        end
      end

      def message_from(response)
      end

      def post_data(action, parameters = {})
        post = {}
        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end ##END: post_Data

    end
  end
end
