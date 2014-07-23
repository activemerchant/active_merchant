module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    HPCI_CONST = {
        #HPCI Actions
        :PXY_AUTH => '/iSynSApp/paymentAuth.action',
        :PXY_SALE => '/iSynSApp/paymentSale.action',
        :PXY_CAPTURE => '/iSynSApp/paymentCapture.action',
        :PXY_CREDIT  => '/iSynSApp/paymentCredit.action',
        :PXY_VOID => '/iSynSApp/paymentVoid.action',

        #Baseline API Parameters
        :PXYPARAM_APIVERSION => 'apiVersion',
        :PXYPARAM_APITYPE => 'apiType',
        :PXYPARAM_APITYPE_PXYHPCI => 'pxyhpci',
        :PXYPARAM_USERNAME => 'userName',
        :PXYPARAM_USERPASSKEY => 'userPassKey',

        :PXYPARAM_PXY_TRANSACTION_CUSISO => 'pxyTransaction.txnCurISO',
        :PXYPARAM_PXY_TRANSACTION_AMOUNT => 'pxyTransaction.txnAmount',
        :PXYPARAM_PXY_TRANSACTION_MER_REFID_NAME => 'pxyTransaction.merchantRefIdName',
        :PXYPARAM_PXY_TRANSACTION_MER_REFID => 'pxyTransaction.merchantRefId',
        :PXYPARAM_PXY_TRANSACTION_PROCESSOR_REFID => 'pxyTransaction.processorRefId',

        #3D Secure Constants
        :PXYPARAM_PXY_3DSECAUTH_ACTIONNAME => 'pxyThreeDSecAuth.actionName',
        :PXYPARAM_PXY_3DSECAUTH_AUTHTXNID => 'pxyThreeDSecAuth.authTxnId',
        :PXYPARAM_PXY_3DSECAUTH_AUTHSTATUS => 'pxyThreeDSecAuth.authStatus',
        :PXYPARAM_PXY_3DSECAUTH_SIGNATURESTATUS => 'pxyThreeDSecAuth.signatureStatus',
        :PXYPARAM_PXY_3DSECAUTH_AUTHCAVV => 'pxyThreeDSecAuth.authCAVV',
        :PXYPARAM_PXY_3DSECAUTH_AUTHECI => 'pxyThreeDSecAuth.authECI',
        :PXYPARAM_PXY_3DSECAUTH_AUTHACSURL => 'pxyThreeDSecAuth.authAcsUrl',
        :PXYPARAM_PXY_3DSECAUTH_PAREQ => 'pxyThreeDSecAuth.paReq',
        :PXYPARAM_PXY_3DSECAUTH_PARES => 'pxyThreeDSecAuth.paRes',
        :PXYPARAM_PXY_3DSECAUTH_AUTHSIGN_COMBOLIST => 'pxyThreeDSecAuth.authSignComboList',

        :PXYPARAM_PXY_CC_CARDTYPE => 'pxyCreditCard.cardType',
        :PXYPARAM_PXY_CC_NUMBER => 'pxyCreditCard.creditCardNumber',
        :PXYPARAM_PXY_CC_EXPMONTH => 'pxyCreditCard.expirationMonth',
        :PXYPARAM_PXY_CC_EXPYEAR => 'pxyCreditCard.expirationYear',
        :PXYPARAM_PXY_CC_CVV => 'pxyCreditCard.cardCodeVerification',

        :PXYPARAM_PXY_CUSTINFO_CUSTOMERID => 'pxyCustomerInfo.customerId',
        :PXYPARAM_PXY_CUSTINFO_EMAIL => 'pxyCustomerInfo.email',
        :PXYPARAM_PXY_CUSTINFO_INSTR => 'pxyCustomerInfo.instructions',
        :PXYPARAM_PXY_CUSTINFO_CUSTIP => 'pxyCustomerInfo.customerIP',

        :PXYPARAM_PXY_CUSTINFO_BILLADDR_FIRSTNAME => 'pxyCustomerInfo.billingLocation.firstName',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_LASTNAME => 'pxyCustomerInfo.billingLocation.lastName',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_COMPANYNAME => 'pxyCustomerInfo.billingLocation.companyName',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_ADDRESS => 'pxyCustomerInfo.billingLocation.address',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_CITY => 'pxyCustomerInfo.billingLocation.city',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_STATE => 'pxyCustomerInfo.billingLocation.state',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_ZIPCODE => 'pxyCustomerInfo.billingLocation.zipCode',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_COUNTRY => 'pxyCustomerInfo.billingLocation.country',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_PHONENUMBER => 'pxyCustomerInfo.billingLocation.phoneNumber',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_FAX => 'pxyCustomerInfo.billingLocation.fax',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_TAX1 => 'pxyCustomerInfo.billingLocation.tax1',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_TAX2 => 'pxyCustomerInfo.billingLocation.tax2',
        :PXYPARAM_PXY_CUSTINFO_BILLADDR_TAX3 => 'pxyCustomerInfo.billingLocation.tax3',

        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_FIRSTNAME => 'pxyCustomerInfo.shippingLocation.firstName',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_LASTNAME => 'pxyCustomerInfo.shippingLocation.lastName',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_COMPANYNAME => 'pxyCustomerInfo.shippingLocation.companyName',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_ADDRESS => 'pxyCustomerInfo.shippingLocation.address',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_CITY => 'pxyCustomerInfo.shippingLocation.city',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_STATE => 'pxyCustomerInfo.shippingLocation.state',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_ZIPCODE => 'pxyCustomerInfo.shippingLocation.zipCode',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_COUNTRY => 'pxyCustomerInfo.shippingLocation.country',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_PHONENUMBER => 'pxyCustomerInfo.shippingLocation.phoneNumber',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_FAX => 'pxyCustomerInfo.shippingLocation.fax',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_TAX1 => 'pxyCustomerInfo.shippingLocation.tax1',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_TAX2 => 'pxyCustomerInfo.shippingLocation.tax2',
        :PXYPARAM_PXY_CUSTINFO_SHIPADDR_TAX3 => 'pxyCustomerInfo.shippingLocation.tax3',

        :PXYPARAM_PXY_ORDER_INVNUM => 'pxyOrder.invoiceNumber',
        :PXYPARAM_PXY_ORDER_DESC => 'pxyOrder.description',
        :PXYPARAM_PXY_ORDER_TOTALAMT => 'pxyOrder.totalAmount',
        :PXYPARAM_PXY_ORDER_SHIPPINGAMT => 'pxyOrder.shippingAmount',

        :PXYPARAM_PXY_ORDER_ORDERITEMS => 'pxyOrder.orderItems[',
        :PXYPARAM_PXY_ORDER_ORDERITEM_ID => '].itemId',
        :PXYPARAM_PXY_ORDER_ORDERITEM_NAME => '].itemName',
        :PXYPARAM_PXY_ORDER_ORDERITEM_DESC => '].itemDescription',
        :PXYPARAM_PXY_ORDER_ORDERITEM_QTY => '].itemQuantity',
        :PXYPARAM_PXY_ORDER_ORDERITEM_PRICE => '].itemPrice',
        :PXYPARAM_PXY_ORDER_ORDERITEM_TAXABLE => '].itemTaxable',

        #response parameters
        :PXYRESP_CALL_STATUS => 'status',
        :PXYRESP_RESPONSE_STATUS => 'pxyResponse.responseStatus',
        :PXYRESP_PROCESSOR_REFID => 'pxyResponse.processorRefId',
        :PXYRESP_RESPSTATUS_NAME => 'pxyResponse.responseStatus.name',
        :PXYRESP_RESPSTATUS_CODE => 'pxyResponse.responseStatus.code',
        :PXYRESP_RESPSTATUS_DESCRIPTION => 'pxyResponse.responseStatus.description',
        :PXYRESP_PROCESSOR_TYPE => 'pxyResponse.processorType',
        :PXYRESP_FULL_NATIVE_RESP => 'pxyResponse.fullNativeResp',
        :PXYRESP_FULL_FRAUD_NATIVE_RESP => 'pxyResponse.fullFraudNativeResp',

        #CVV and AVS response parameters
        :PXYRESP_AVS1 => 'pxyResponse.responseAVS1',
        :PXYRESP_AVS2 => 'pxyResponse.responseAVS2',
        :PXYRESP_AVS3 => 'pxyResponse.responseAVS3',
        :PXYRESP_AVS4 => 'pxyResponse.responseAVS4',
        :PXYRESP_CVV1 => 'pxyResponse.responseCVV1',
        :PXYRESP_CVV2 => 'pxyResponse.responseCVV2',

        #3D Secure responses
        :PXYRESP_3DS_ACS_URL =>  'pxyResponse.threeDSAcsUrl',
        :PXYRESP_3DS_TRANS_ID => 'pxyResponse.threeDSTransactionId',
        :PXYRESP_3DS_PA_REQ =>   'pxyResponse.threeDSPARequest',

        #3D Secure Actions
        :ACTIONNAME_VERIFYENROLL =>  'verifyenroll',
        :ACTIONNAME_REQUESTPIN =>    'requestpin',
        :ACTIONNAME_VERIFYRESP =>    'verifyresp',


        :PXYRESP_CALL_STATUS_SUCCESS => 'success',
        :PXYRESP_CALL_STATUS_ERROR => 'error',

        :PXYRESP_CALL_ERRID => 'errId',
        :PXYRESP_CALL_ERRMSG => 'errMsg',

        :PXYRESP_RESPONSE_STATUS_APPROVED => 'approved',
        :PXYRESP_RESPONSE_STATUS_DECLINED => 'declined',
        :PXYRESP_RESPONSE_STATUS_ERROR => 'error',
        :PXYRESP_RESPONSE_STATUS_REVIEW => 'review',
        :PXYRESP_RESPONSE_STATUS_3DSECURE => '3dsecure',

        :NL => "\n"
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
        post[HPCI_CONST[:PXYPARAM_APIVERSION]] = '1.0.1'
        post[HPCI_CONST[:PXYPARAM_APITYPE]] = HPCI_CONST[:PXYPARAM_APITYPE_PXYHPCI]
        post[HPCI_CONST[:PXYPARAM_USERNAME]] = @options[:login]
        post[HPCI_CONST[:PXYPARAM_USERPASSKEY]] = @options[:password]

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
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_EMAIL]] = options[:email]
        end

        if options.has_key? :customer
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_CUSTOMERID]] = options[:customer]
        end

        if options.has_key? :ip
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_CUSTIP]] = options[:ip]
        end
      end ##END: add_customer_data

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_BILLADDR_FIRSTNAME]] = address[:name].to_s.split[0] if !address[:name].to_s.split[0].blank?
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_BILLADDR_LASTNAME]]  = address[:name].to_s.split[1] if !address[:name].to_s.split[1].blank?
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_BILLADDR_ADDRESS]]   = address[:address1].to_s
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_BILLADDR_ZIPCODE]]   = address[:zip].to_s
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_BILLADDR_CITY]]      = address[:city].to_s
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_BILLADDR_COUNTRY]]   = address[:country].to_s
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_BILLADDR_STATE]]     = address[:state].blank?  ? 'n/a' : address[:state]
        end

        if address = options[:shipping_address]
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_SHIPADDR_FIRSTNAME]] = address[:name].to_s.split[0] if !address[:name].to_s.split[0].blank?
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_SHIPADDR_LASTNAME]]  = address[:name].to_s.split[1] if !address[:name].to_s.split[1].blank?
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_SHIPADDR_ADDRESS]]   = address[:address1].to_s
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_SHIPADDR_ZIPCODE]]   = address[:zip].to_s
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_SHIPADDR_CITY]]      = address[:city].to_s
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_SHIPADDR_COUNTRY]]   = address[:country].to_s
          post[HPCI_CONST[:PXYPARAM_PXY_CUSTINFO_SHIPADDR_STATE]]     = address[:state].blank?  ? 'n/a' : address[:state]
        end
      end ##END: add_address

      def add_invoice(post, options)
        if options.has_key? :order_id
          post[HPCI_CONST[:PXYPARAM_PXY_ORDER_INVNUM]] = options[:order_id]
          post[HPCI_CONST[:PXYPARAM_PXY_TRANSACTION_MER_REFID]] = "merRef:" + options[:order_id]
        end
        if options.has_key? :description
          post[HPCI_CONST[:PXYPARAM_PXY_ORDER_DESC]]   = options[:description]
        end
      end

      def add_creditcard(post, creditcard)
        post[HPCI_CONST[:PXYPARAM_PXY_CC_NUMBER]]   = creditcard.number
        post[HPCI_CONST[:PXYPARAM_PXY_CC_CVV]]  = creditcard.verification_value if creditcard.verification_value?
        post[HPCI_CONST[:PXYPARAM_PXY_CC_EXPMONTH]]   = creditcard.month.to_s
        post[HPCI_CONST[:PXYPARAM_PXY_CC_EXPYEAR]]   = creditcard.year.to_s
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
          serviceUrl = HPCI_CONST[:PXY_SALE]
        elsif action =='authonly'
          serviceUrl = HPCI_CONST[:PXY_AUTH]
        elsif action == 'capture'
          serviceUrl = HPCI_CONST[:PXY_CAPTURE]
        elsif action =='void'
          serviceUrl = HPCI_CONST[:PXY_VOID]
        elsif action == 'credit'
          serviceUrl = HPCI_CONST[:PXY_CREDIT]
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
            (response[:payment_status] == HPCI_CONST[:PXYRESP_RESPONSE_STATUS_APPROVED])
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
          put_in_map results, :call_status, responseHash[HPCI_CONST[:PXYRESP_CALL_STATUS]]
          put_in_map results, :error_id, responseHash[HPCI_CONST[:PXYRESP_CALL_ERRID]]
          put_in_map results, :error_msg, responseHash[HPCI_CONST[:PXYRESP_CALL_ERRMSG]]
          put_in_map results, :payment_status, responseHash[HPCI_CONST[:PXYRESP_RESPONSE_STATUS]]
          put_in_map results, :status_code, responseHash[HPCI_CONST[:PXYRESP_RESPSTATUS_CODE]]
          put_in_map results, :status_name, responseHash[HPCI_CONST[:PXYRESP_RESPSTATUS_NAME]]
          put_in_map results, :status_description, responseHash[HPCI_CONST[:PXYRESP_RESPSTATUS_DESCRIPTION]]
          put_in_map results, :processor_refid, responseHash[HPCI_CONST[:PXYRESP_PROCESSOR_REFID]]
          put_in_map results, :processor_type, responseHash[HPCI_CONST[:PXYRESP_PROCESSOR_TYPE]]
          put_in_map results, :processor_native_response, responseHash[HPCI_CONST[:PXYRESP_FULL_NATIVE_RESP]]
          put_in_map results, :processor_native_fraud_response, responseHash[HPCI_CONST[:PXYRESP_FULL_FRAUD_NATIVE_RESP]]
          put_in_map results, :avs1_response, responseHash[HPCI_CONST[:PXYRESP_AVS1]]
          put_in_map results, :avs2_response, responseHash[HPCI_CONST[:PXYRESP_AVS2]]
          put_in_map results, :avs3_response, responseHash[HPCI_CONST[:PXYRESP_AVS3]]
          put_in_map results, :avs4_response, responseHash[HPCI_CONST[:PXYRESP_AVS4]]
          put_in_map results, :cvv1_response, responseHash[HPCI_CONST[:PXYRESP_CVV1]]
          put_in_map results, :cvv2_response, responseHash[HPCI_CONST[:PXYRESP_CVV2]]
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
