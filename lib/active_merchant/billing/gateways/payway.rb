module ActiveMerchant
  module Billing
    class PaywayGateway < Gateway
      self.live_url = self.test_url = 'https://ccapi.client.qvalent.com/payway/ccapi'

      self.supported_countries = [ 'AU' ]
      self.supported_cardtypes = [ :visa, :master, :diners_club, :american_express, :bankcard ]
      self.display_name        = 'Pay Way'
      self.homepage_url        = 'http://www.payway.com.au'
      self.default_currency    = 'AUD'
      self.money_format        = :cents

      SUMMARY_CODES = {
        '0' => 'Approved',
        '1' => 'Declined',
        '2' => 'Erred',
        '3' => 'Rejected'
      }

      RESPONSE_CODES= {
        '00' => 'Approved or completed successfully',
        '01' => 'Refer to card issuer',
        '02' => 'Refer to card issuers special conditions',
        '03' => 'Invalid merchant',
        '04' => 'Pick-up card',
        '05' => 'Do not honor',
        '06' => 'Error',
        '07' => 'Pick-up card, special condition',
        '08' => 'Honor with identification',
        '09' => 'Request in progress',
        '10' => 'Approved for partial amount',
        '11' => 'Approved VIP',
        '12' => 'Invalid transaction',
        '13' => 'Invalid amount',
        '14' => 'Invalid card number (no such number)',
        '15' => 'No such issuer',
        '16' => 'Approved, update Track 3',
        '17' => 'Customer cancellation',
        '18' => 'Customer dispute',
        '19' => 'Re-enter transaction',
        '20' => 'Invalid response',
        '21' => 'No action taken',
        '22' => 'Suspected malfunction',
        '23' => 'Unacceptable transaction fee',
        '24' => 'File update not supported by receiver',
        '25' => 'Unable to locate record on file',
        '26' => 'Duplicate file update record, old record replaced',
        '27' => 'File update field edit error',
        '28' => 'File update file locked out',
        '29' => 'File update not successful, contact acquirer',
        '30' => 'Format error',
        '31' => 'Bank not supported by switch',
        '32' => 'Completed partially',
        '33' => 'Expired card',
        '34' => 'Suspected fraud',
        '35' => 'Card acceptor contact acquirer',
        '36' => 'Restricted card',
        '37' => 'Card acceptor call acquirer security',
        '38' => 'Allowable PIN tries exceeded',
        '39' => 'No credit account',
        '40' => 'Request function not supported',
        '41' => 'Lost card',
        '42' => 'No universal account',
        '43' => 'Stolen card, pick up',
        '44' => 'No investment account',
        '51' => 'Not sufficient funds',
        '52' => 'No cheque account',
        '53' => 'No savings account',
        '54' => 'Expired card',
        '55' => 'Incorrect PIN',
        '56' => 'No card record',
        '57' => 'Transaction not permitted to cardholder',
        '58' => 'Transaction not permitted to terminal',
        '59' => 'Suspected fraud',
        '60' => 'Card acceptor contact acquirer',
        '61' => 'Exceeds withdrawal amount limits',
        '62' => 'Restricted card',
        '63' => 'Security violation',
        '64' => 'Original amount incorrect',
        '65' => 'Exceeds withdrawal frequency limit',
        '66' => 'Card acceptor call acquirers security department',
        '67' => 'Hard capture (requires that card be picked up at ATM)',
        '68' => 'Response received too late',
        '75' => 'Allowable number of PIN tries exceeded',
        '90' => 'Cutoff is in process (Switch ending a day\'s business and starting the next. The transaction can be sent again in a few minutes).',
        '91' => 'Issuer or switch is inoperative',
        '92' => 'Financial institution or intermediate network facility cannot be found for routing',
        '93' => 'Transaction cannot be completed. Violation of law',
        '94' => 'Duplicate transmission',
        '95' => 'Reconcile error',
        '96' => 'System malfunction',
        '97' => 'Advises that reconciliation totals have been reset',
        '98' => 'MAC error',
        '99' => 'Reserved for national use',
        'EA' => 'response text varies depending on reason for error',
        'EG' => 'response text varies depending on reason for error',
        'EM' => 'Error at the Merchant Server level',
        'N1' => 'Unknown Error', # NZ Only
        'N2' => 'Bank Declined Transaction', # NZ Only
        'N3' => 'No Reply from Bank', # NZ Only
        'N4' => 'Expired Card', # NZ Only
        'N5' => 'Insufficient Funds', # NZ Only
        'N6' => 'Error Communicating with Bank', # NZ Only
        'N7' => 'Payment Server System Error', # NZ Only
        'N8' => 'Transaction Type Not Supported', # NZ Only
        'N9' => 'Bank declined transaction', # NZ Only
        'NA' => 'Transaction aborted', # NZ Only
        'NC' => 'Transaction cancelled', # NZ Only
        'ND' => 'Deferred Transaction', # NZ Only
        'NF' => '3D Secure Authentication Failed', # NZ Only
        'NI' => 'Card Security Code Failed', # NZ Only
        'NL' => 'Transaction Locked', # NZ Only
        'NN' => 'Cardholder is not enrolled in 3D Secure', # NZ Only
        'NP' => 'Transaction is Pending', # NZ Only
        'NR' => 'Retry Limits Exceeded, Transaction Not Processed', # NZ Only
        'NT' => 'Address Verification Failed', # NZ Only
        'NU' => 'Card Security Code Failed', # NZ Only
        'NV' => 'Address Verification and Card Security Code Failed', # NZ Only
        'Q1' => 'Unknown Buyer',
        'Q2' => 'Transaction Pending',
        'Q3' => 'Payment Gateway Connection Error',
        'Q4' => 'Payment Gateway Unavailable',
        'Q5' => 'Invalid Transaction',
        'Q6' => 'Duplicate Transaction - requery to determine status',
        'QA' => 'Invalid parameters',
        'QB' => 'Order type not currently supported',
        'QC' => 'Invalid Order Type',
        'QD' => 'Invalid Payment Amount - Payment amount less than minimum/exceeds maximum allowed limit',
        'QE' => 'Internal Error',
        'QF' => 'Transaction Failed',
        'QG' => 'Unknown Customer Order Number',
        'QH' => 'Unknown Customer Username',
        'QI' => 'Transaction incomplete - contact Westpac to confirm reconciliation',
        'QJ' => 'Incorrect Customer Password',
        'QK' => 'Unknown Customer Merchant',
        'QL' => 'Business Group not configured for customer',
        'QM' => 'Payment Instrument not configured for customer',
        'QN' => 'Configuration Error',
        'QO' => 'Missing Payment Instrument',
        'QP' => 'Missing Supplier Account',
        'QQ' => 'Invalid Credit Card \\ Invalid Credit Card Verification Number',
        'QR' => 'Transaction Retry',
        'QS' => 'Transaction Successful',
        'QT' => 'Invalid currency',
        'QU' => 'Unknown Customer IP Address',
        'QV' => 'Invalid Capture Order Number specified for Refund, Refund amount exceeds capture amount, or Previous capture was not approved',
        'QW' => 'Invalid Reference Number',
        'QX' => 'Network Error has occurred',
        'QY' => 'Card Type Not Accepted',
        'QZ' => 'Zero value transaction',
        'RA' => 'response text varies depending on reason for rejection',
        'RG' => 'response text varies depending on reason for rejection',
        'RM' => 'Rejected at the Merchant Server level',
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

        message = "#{SUMMARY_CODES[params[:summary_code]]} - #{RESPONSE_CODES[params[:response_code]]}"

        success = (params[:summary_code] ? (params[:summary_code] == "0") : (params[:response_code] == "00"))

        Response.new(success, message, params,
          :test => (@options[:merchant].to_s == "TEST"),
          :authorization => post[:order_number]
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
