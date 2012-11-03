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
        '00' => 'Completed Successfully',
        '01' => 'Refer to card issuer',
        '03' => 'Invalid merchant',
        '04' => 'Pick-up card',
        '05' => 'Do not honour',
        '08' => 'Honour only with identification',
        '12' => 'Invalid transaction',
        '13' => 'Invalid amount',
        '14' => 'Invalid card number (no such number)',
        '30' => 'Format error',
        '36' => 'Restricted card',
        '41' => 'Lost card',
        '42' => 'No universal card',
        '43' => 'Stolen card',
        '51' => 'Not sufficient funds',
        '54' => 'Expired card',
        '61' => 'Exceeds withdrawal amount limits',
        '62' => 'Restricted card',
        '65' => 'Exceeds withdrawal frequency limit',
        '91' => 'Issuer or switch is inoperative',
        '92' => 'Financial institution or intermediate network facility cannot be found for routing',
        '94' => 'Duplicate transmission',
        'Q1' => 'Unknown Buyer',
        'Q2' => 'Transaction Pending',
        'Q3' => 'Payment Gateway Connection Error',
        'Q4' => 'Payment Gateway Unavailable',
        'Q5' => 'Invalid Transaction',
        'Q6' => 'Duplicate Transaction - requery to determine status',
        'QA' => 'Invalid parameters or Initialisation failed',
        'QB' => 'Order type not currently supported',
        'QC' => 'Invalid Order Type',
        'QD' => 'Invalid Payment Amount - Payment amount less than minimum/exceeds maximum allowed limit',
        'QE' => 'Internal Error',
        'QF' => 'Transaction Failed',
        'QG' => 'Unknown Customer Order Number',
        'QH' => 'Unknown Customer Username or Password',
        'QI' => 'Transaction incomplete - contact Westpac to confirm reconciliation',
        'QJ' => 'Invalid Client Certificate',
        'QK' => 'Unknown Customer Merchant',
        'QL' => 'Business Group not configured for customer',
        'QM' => 'Payment Instrument not configured for customer',
        'QN' => 'Configuration Error',
        'QO' => 'Missing Payment Instrument',
        'QP' => 'Missing Supplier Account',
        'QQ' => 'Invalid Credit Card Verification Number',
        'QR' => 'Transaction Retry',
        'QS' => 'Transaction Successful',
        'QT' => 'Invalid currency',
        'QU' => 'Unknown Customer IP Address',
        'QV' => 'Invalid Original Order Number specified for Refund, Refund amount exceeds capture amount, or Previous capture was not approved',
        'QW' => 'Invalid Reference Number',
        'QX' => 'Network Error has occurred',
        'QY' => 'Card Type Not Accepted',
        'QZ' => 'Zero value transaction'
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
