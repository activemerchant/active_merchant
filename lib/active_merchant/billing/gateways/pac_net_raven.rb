module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PacNetRavenGateway < Gateway

      AVS_ADDRESS_CODES = {
        'avs_address_unavailable'   => 'X',
        'avs_address_not_checked'   => 'X',
        'avs_address_matched'       => 'Y',
        'avs_address_not_matched'   => 'N',
        'avs_address_partial_match' => 'N'
      }

      AVS_POSTAL_CODES = {
        'avs_postal_unavailable'   => 'X',
        'avs_postal_not_checked'   => 'X',
        'avs_postal_matched'       => 'Y',
        'avs_postal_not_matched'   => 'N',
        'avs_postal_partial_match' => 'N'
      }

      CVV2_CODES = {
        'cvv2_matched'     => 'Y',
        'cvv2_not_matched' => 'N',
        'cvv2_unavailable' => 'X',
        'cvv2_not_checked' => 'X'
      }

      self.test_url = 'https://demo.deepcovelabs.com/realtime/'
      self.live_url = 'https://raven.pacnetservices.com/realtime/'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master]
      self.money_format = :cents
      self.default_currency = 'USD'
      self.homepage_url = 'http://www.pacnetservices.com/'
      self.display_name = 'Raven PacNet'

      def initialize(options = {})
        requires!(options, :user, :secret, :prn)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard)
        add_currency_code(post, money, options)
        add_address(post, options)
        post['PRN'] = @options[:prn]

        commit('cc_preauth', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_currency_code(post, money, options)
        add_creditcard(post, creditcard)
        add_address(post, options)
        post['PRN'] = @options[:prn]

        commit('cc_debit', money, post)
      end

      def void(authorization, options = {})
        post = {}
        post['TrackingNumber'] = authorization
        post['PymtType'] = options[:pymt_type] || 'cc_debit'

        commit('void', nil, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        post['PreauthNumber'] = authorization
        post['PRN'] = @options[:prn]
        add_currency_code(post, money, options)

        commit('cc_settle', money, post)
      end

      def refund(money, template_number, options = {})
        post = {}
        post['PRN'] = @options[:prn]
        post['TemplateNumber'] = template_number
        add_currency_code(post, money, options)

        commit('cc_refund', money, post)
      end

      private

      def add_creditcard(post, creditcard)
        post['CardNumber'] = creditcard.number
        post['Expiry'] = expdate(creditcard)
        post['CVV2'] = creditcard.verification_value if creditcard.verification_value
      end

      def add_currency_code(post, money, options)
        post['Currency'] = options[:currency] || currency(money)
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post['BillingStreetAddressLineOne']   = address[:address1].to_s
          post['BillingStreetAddressLineFour']  = address[:address2].to_s
          post['BillingPostalCode']             = address[:zip].to_s
        end
      end

      def parse(body)
        Hash[body.split('&').map{|x| x.split('=').map{|y| CGI.unescape(y)}}]
      end

      def commit(action, money, parameters)
        parameters['Amount'] = amount(money) unless action == 'void'

        data = ssl_post url(action), post_data(action, parameters)

        response = parse(data)
        response[:action] = action

        message = message_from(response)

        test_mode = test? || message =~ /TESTMODE/

        Response.new(success?(response), message, response,
          :test => test_mode,
          :authorization => response['TrackingNumber'],
          :fraud_review => fraud_review?(response),
          :avs_result => {
                          :postal_match => AVS_POSTAL_CODES[response['AVSPostalResponseCode']],
                          :street_match => AVS_ADDRESS_CODES[response['AVSAddressResponseCode']]
                         },
          :cvv_result => CVV2_CODES[response['CVV2ResponseCode']]
        )
      end

      def url(action)
        (test? ? self.test_url : self.live_url) + endpoint(action)
      end

      def endpoint(action)
        return 'void' if action == 'void'
        'submit'
      end

      def fraud_review?(response)
        false
      end

      def success?(response)
        if %w(cc_settle cc_debit cc_preauth cc_refund).include?(response[:action])
          !response['ApprovalCode'].nil? and response['ErrorCode'].nil? and response['Status'] == 'Approved'
        elsif response[:action] = 'void'
          !response['ApprovalCode'].nil? and response['ErrorCode'].nil? and response['Status'] == 'Voided'
        end
      end

      def message_from(response)
        return response['Message'] if response['Message']

        if response['Status'] == 'Approved'
          "This transaction has been approved"
        elsif response['Status'] == 'Declined'
          "This transaction has been declined"
        elsif response['Status'] == 'Voided'
          "This transaction has been voided"
        else
          response['Status']
        end
      end

      def post_data(action, parameters = {})
        post = {}

        post['PymtType']      = action
        post['RAPIVersion']   = '2'
        post['UserName']      = @options[:user]
        post['Timestamp']     = timestamp
        post['RequestID']     = request_id
        post['Signature']     = signature(action, post, parameters)

        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end

      def timestamp
        Time.now.strftime("%Y-%m-%dT%H:%M:%S.Z")
      end

      def request_id
        SecureRandom.uuid
      end

      def signature(action, post, parameters = {})
        string = if %w(cc_settle cc_debit cc_preauth cc_refund).include?(action)
          post['UserName'] + post['Timestamp'] + post['RequestID'] + post['PymtType'] + parameters['Amount'].to_s + parameters['Currency']
        elsif action == 'void'
          post['UserName'] + post['Timestamp'] + post['RequestID'] + parameters['TrackingNumber']
        else
          post['UserName']
        end
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new(@options[:secret]), @options[:secret], string)
      end
    end
  end
end

