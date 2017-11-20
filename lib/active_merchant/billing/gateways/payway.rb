module ActiveMerchant
  module Billing
    class PaywayGateway < Gateway
      self.live_url = self.test_url = 'https://ccapi.client.qvalent.com/payway/ccapi'

      self.supported_countries = [ 'AU' ]
      self.supported_cardtypes = [ :visa, :master, :diners_club, :american_express, :bankcard ]
      self.display_name        = 'PayWay'
      self.homepage_url        = 'http://www.payway.com.au'
      self.default_currency    = 'AUD'
      self.money_format        = :cents

      SUMMARY_CODES = {
        '0' => 'Approved',
        '1' => 'Declined',
        '2' => 'Erred',
        '3' => 'Rejected'
      }

      DEFAULT_ERROR_CODE = :processing_error

      RESPONSE_CODES = {
        '00' => [nil,                'Approved or completed successfully'],
        '01' => [:call_issuer,       'Refer to card issuer'],
        '02' => [:call_issuer,       'Refer to card issuers special conditions'],
        '03' => [:processing_error,  'Invalid merchant'],
        '04' => [:pickup_card,       'Pick-up card'],
        '05' => [:card_declined,     'Do not honor'],
        '06' => [:processing_error,  'Error'],
        '07' => [:pickup_card,       'Pick-up card, special condition'],
        '08' => [nil,                'Honor with identification'],
        '09' => [nil,                'Request in progress'],
        '10' => [nil,                'Approved for partial amount'],
        '11' => [nil,                'Approved VIP'],
        '12' => [:processing_error,  'Invalid transaction'],
        '13' => [:processing_error,  'Invalid amount'],
        '14' => [:invalid_number,    'Invalid card number (no such number)'],
        '15' => [:processing_error,  'No such issuer'],
        '16' => [nil,                'Approved, update Track 3'],
        '17' => [:processing_error,  'Customer cancellation'],
        '18' => [:processing_error,  'Customer dispute'],
        '19' => [:processing_error,  'Re-enter transaction'],
        '20' => [:processing_error,  'Invalid response'],
        '21' => [:processing_error,  'No action taken'],
        '22' => [:processing_error,  'Suspected malfunction'],
        '23' => [:processing_error,  'Unacceptable transaction fee'],
        '24' => [:processing_error,  'File update not supported by receiver'],
        '25' => [:processing_error,  'Unable to locate record on file'],
        '26' => [:processing_error,  'Duplicate file update record, old record replaced'],
        '27' => [:processing_error,  'File update field edit error'],
        '28' => [:processing_error,  'File update file locked out'],
        '29' => [:processing_error,  'File update not successful, contact acquirer'],
        '30' => [:processing_error,  'Format error'],
        '31' => [:processing_error,  'Bank not supported by switch'],
        '32' => [:processing_error,  'Completed partially'],
        '33' => [:expired_card,      'Expired card'],
        '34' => [:card_declined,     'Suspected fraud'],
        '35' => [:call_issuer,       'Card acceptor contact acquirer'],
        '36' => [:card_declined,     'Restricted card'],
        '37' => [:call_issuer,       'Card acceptor call acquirer security'],
        '38' => [:card_declined,     'Allowable PIN tries exceeded'],
        '39' => [:card_declined,     'No credit account'],
        '40' => [:processing_error,  'Request function not supported'],
        '41' => [:card_declined,     'Lost card'],
        '42' => [:processing_error,  'No universal account'],
        '43' => [:pickup_card,       'Stolen card, pick up'],
        '44' => [:card_declined,     'No investment account'],
        '51' => [:card_declined,     'Not sufficient funds'],
        '52' => [:card_declined,     'No cheque account'],
        '53' => [:card_declined,     'No savings account'],
        '54' => [:expired_card,      'Expired card'],
        '55' => [:card_declined,     'Incorrect PIN'],
        '56' => [:processing_error,  'No card record'],
        '57' => [:card_declined,     'Transaction not permitted to cardholder'],
        '58' => [:processing_error,  'Transaction not permitted to terminal'],
        '59' => [:card_declined,     'Suspected fraud'],
        '60' => [:call_issuer,       'Card acceptor contact acquirer'],
        '61' => [:card_declined,     'Exceeds withdrawal amount limits'],
        '62' => [:card_declined,     'Restricted card'],
        '63' => [:card_declined,     'Security violation'],
        '64' => [:processing_error,  'Original amount incorrect'],
        '65' => [:card_declined,     'Exceeds withdrawal frequency limit'],
        '66' => [:call_issuer,       'Card acceptor call acquirers security department'],
        '67' => [:pickup_card,       'Hard capture (requires that card be picked up at ATM)'],
        '68' => [:processing_error,  'Response received too late'],
        '75' => [:card_declined,     'Allowable number of PIN tries exceeded'],
        '90' => [:processing_error,  'Cutoff is in process (Switch ending a day\'s business and starting the next. The transaction can be sent again in a few minutes).'],
        '91' => [:processing_error,  'Issuer or switch is inoperative'],
        '92' => [:processing_error,  'Financial institution or intermediate network facility cannot be found for routing'],
        '93' => [:processing_error,  'Transaction cannot be completed. Violation of law'],
        '94' => [:processing_error,  'Duplicate transmission'],
        '95' => [:processing_error,  'Reconcile error'],
        '96' => [:processing_error,  'System malfunction'],
        '97' => [:processing_error,  'Advises that reconciliation totals have been reset'],
        '98' => [:processing_error,  'MAC error'],
        '99' => [:processing_error,  'Reserved for national use'],
        'EA' => [:processing_error,  'response text varies depending on reason for error'],
        'EG' => [:processing_error,  'response text varies depending on reason for error'],
        'EM' => [:processing_error,  'Error at the Merchant Server level'],
        'N1' => [:processing_error,  'Unknown Error'], # NZ Only
        'N2' => [:card_declined,     'Bank Declined Transaction'], # NZ Only
        'N3' => [:processing_error,  'No Reply from Bank'], # NZ Only
        'N4' => [:expired_card,      'Expired Card'], # NZ Only
        'N5' => [:card_declined,     'Insufficient Funds'], # NZ Only
        'N6' => [:processing_error,  'Error Communicating with Bank'], # NZ Only
        'N7' => [:processing_error,  'Payment Server System Error'], # NZ Only
        'N8' => [:processing_error,  'Transaction Type Not Supported'], # NZ Only
        'N9' => [:card_declined,     'Bank declined transaction'], # NZ Only
        'NA' => [:processing_error,  'Transaction aborted'], # NZ Only
        'NC' => [:processing_error,  'Transaction cancelled'], # NZ Only
        'ND' => [:processing_error,  'Deferred Transaction'], # NZ Only
        'NF' => [:card_declined,     '3D Secure Authentication Failed'], # NZ Only
        'NI' => [:incorrect_cvc,     'Card Security Code Failed'], # NZ Only
        'NL' => [:processing_error,  'Transaction Locked'], # NZ Only
        'NN' => [:processing_error,  'Cardholder is not enrolled in 3D Secure'], # NZ Only
        'NP' => [nil,                'Transaction is Pending'], # NZ Only
        'NR' => [:card_declined,     'Retry Limits Exceeded, Transaction Not Processed'], # NZ Only
        'NT' => [:incorrect_address, 'Address Verification Failed'], # NZ Only
        'NU' => [:incorrect_cvc,     'Card Security Code Failed'], # NZ Only
        'NV' => [:processing_error,  'Address Verification and Card Security Code Failed'], # NZ Only
        'Q1' => [:processing_error,  'Unknown Buyer'],
        'Q2' => [nil,                'Transaction Pending'],
        'Q3' => [:processing_error,  'Payment Gateway Connection Error'],
        'Q4' => [:processing_error,  'Payment Gateway Unavailable'],
        'Q5' => [:processing_error,  'Invalid Transaction'],
        'Q6' => [:processing_error,  'Duplicate Transaction - requery to determine status'],
        'QA' => [:processing_error,  'Invalid parameters'],
        'QB' => [:processing_error,  'Order type not currently supported'],
        'QC' => [:processing_error,  'Invalid Order Type'],
        'QD' => [:processing_error,  'Invalid Payment Amount - Payment amount less than minimum/exceeds maximum allowed limit'],
        'QE' => [:processing_error,  'Internal Error'],
        'QF' => [:processing_error,  'Transaction Failed'],
        'QG' => [:processing_error,  'Unknown Customer Order Number'],
        'QH' => [:processing_error,  'Unknown Customer Username'],
        'QI' => [:processing_error,  'Transaction incomplete - contact Westpac to confirm reconciliation'],
        'QJ' => [:processing_error,  'Incorrect Customer Password'],
        'QK' => [:processing_error,  'Unknown Customer Merchant'],
        'QL' => [:processing_error,  'Business Group not configured for customer'],
        'QM' => [:processing_error,  'Payment Instrument not configured for customer'],
        'QN' => [:config_error,      'Configuration Error'],
        'QO' => [:processing_error,  'Missing Payment Instrument'],
        'QP' => [:processing_error,  'Missing Supplier Account'],
        'QQ' => [:invalid_number,    'Invalid Credit Card \\ Invalid Credit Card Verification Number'],
        'QR' => [nil,                'Transaction Retry'],
        'QS' => [nil,                'Transaction Successful'],
        'QT' => [:processing_error,  'Invalid currency'],
        'QU' => [:processing_error,  'Unknown Customer IP Address'],
        'QV' => [:processing_error,  'Invalid Capture Order Number specified for Refund, Refund amount exceeds capture amount, or Previous capture was not approved'],
        'QW' => [:processing_error,  'Invalid Reference Number'],
        'QX' => [:processing_error,  'Network Error has occurred'],
        'QY' => [:processing_error,  'Card Type Not Accepted'],
        'QZ' => [:processing_error,  'Zero value transaction'],
        'RA' => [:processing_error,  'response text varies depending on reason for rejection'],
        'RG' => [:processing_error,  'response text varies depending on reason for rejection'],
        'RM' => [:processing_error,  'Rejected at the Merchant Server level'],
      }

      TRANSACTIONS  = {
        :authorize  => 'preauth',
        :purchase   => 'capture',
        :capture    => 'captureWithoutAuth',
        :status     => 'query',
        :refund     => 'refund',
        :store      => 'registerAccount'
      }

      def initialize(options={})
        @options = options

        @options[:merchant] ||= 'TEST' if test?
        requires!(options, :username, :password, :merchant, :pem)

        @options[:eci] ||= 'SSL'
      end

      def authorize(amount, payment_method, options={})
        requires!(options, :order_id)

        post = {}
        add_payment_method(post, payment_method)
        add_order(post, amount, options)
        commit(:authorize, post)
      end

      def capture(amount, authorization, options={})
        requires!(options, :order_id)

        post = {}
        add_reference(post, authorization)
        add_order(post, amount, options)
        commit(:capture, post)
      end

      def purchase(amount, payment_method, options={})
        requires!(options, :order_id)

        post = {}
        add_payment_method(post, payment_method)
        add_order(post, amount, options)
        commit(:purchase, post)
      end

      def refund(amount, authorization, options={})
        requires!(options, :order_id)

        post = {}
        add_reference(post, authorization)
        add_order(post, amount, options)
        commit(:refund, post)
      end

      def store(credit_card, options={})
        requires!(options, :billing_id)

        post = {}
        add_payment_method(post, credit_card)
        add_payment_method(post, options[:billing_id])
        commit(:store, post)
      end

      def status(options={})
        requires!(options, :order_id)

        commit(:status, 'customer.orderNumber' => options[:order_id])
      end

      private

      def add_payment_method(post, payment_method)
        if payment_method.respond_to?(:number)
          post['card.cardHolderName'] = "#{payment_method.first_name} #{payment_method.last_name}"
          post['card.PAN']            = payment_method.number
          post['card.CVN']            = payment_method.verification_value
          post['card.expiryYear']     = payment_method.year.to_s[-2,2]
          post['card.expiryMonth']    = sprintf('%02d', payment_method.month)
        else
          post['customer.customerReferenceNumber'] = payment_method
        end
      end

      def add_reference(post, reference)
        post['customer.originalOrderNumber'] = reference
      end

      def add_order(post, amount, options)
        post['order.ECI']            = @options[:eci]
        post['order.amount']         = amount
        post['card.currency']        = (options[:currency] || currency(amount))
        post['customer.orderNumber'] = options[:order_id][0...20]
      end

      def add_auth(post)
        post['customer.username'] = @options[:username]
        post['customer.password'] = @options[:password]
        post['customer.merchant'] = @options[:merchant]
      end


      def success_from(response)
        response[:summary_code] ? (response[:summary_code] == "0") : (response[:response_code] == "00")
      end

      def error_code_from(response)
        return nil if success_from(response)
        default = STANDARD_ERROR_CODE[DEFAULT_ERROR_CODE]
        response_code = RESPONSE_CODES[response[:response_code]]
        if response_code and response_code.first
          STANDARD_ERROR_CODE[response_code.first]
        else
          default
        end
      end

      # Creates the request and returns the summarized result
      def commit(action, post)
        add_auth(post)
        post.merge!('order.type' => TRANSACTIONS[action])

        request = post.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
        response = ssl_post(self.live_url, request)

        params = {}
        CGI.parse(response).each_pair do |key, value|
          actual_key = key.split(".").last
          params[actual_key.underscore.to_sym] = value[0]
        end

        message = "#{SUMMARY_CODES[params[:summary_code]]} - #{RESPONSE_CODES[params[:response_code]].last}"

        Response.new(success_from(params), message, params,
          :test => (@options[:merchant].to_s == "TEST"),
          :authorization => post[:order_number],
          :error_code => error_code_from(params),
        )
      rescue ActiveMerchant::ResponseError => e
        raise unless e.response.code == '403'
        return Response.new(false, "Invalid credentials", {}, :test => test?)
      rescue ActiveMerchant::ClientCertificateError
        return Response.new(false, "Invalid certificate", {}, :test => test?)
      end
    end
  end
end
