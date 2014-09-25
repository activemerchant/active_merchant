module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AdyenGateway < Gateway
      self.test_url = 'https://pal-test.adyen.com/pal/adapter/httppost'
      self.live_url = 'https://pal-live.adyen.com/pal/adapter/httppost'

      self.supported_countries = ['AR', 'AT', 'BE', 'BR', 'CA', 'CH', 'CL', 'CN', 'CO', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GB', 'HK', 'ID', 'IE', 'IL', 'IN', 'IT', 'JP', 'KR', 'LU', 'MX', 'MY', 'NL', 'NO', 'PA', 'PE', 'PH', 'PL', 'PT', 'RU', 'SE', 'SG', 'TH', 'TR', 'TW', 'US', 'VN', 'ZA']
      self.default_currency = 'EUR'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :dankort, :maestro]

      self.homepage_url = 'https://www.adyen.com/'
      self.display_name = 'Adyen'

      def initialize(options = {})
        requires!(options, :company, :merchant, :password)
        super
      end

      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        MultiResponse.run do |r|
          r.process { authorize(money, creditcard, options) }
          r.process { capture(money, r.authorization, options) }
        end
      end

      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)

        post = {}
        post[:paymentRequest] = payment_request(money, options)
        post[:paymentRequest][:amount] = amount_hash(money, options[:currency])
        post[:paymentRequest][:card] = credit_card_hash(creditcard)

        if address = (options[:billing_address] || options[:address])
          post[:paymentRequest][:billingAddress] = address_hash(address)
        end

        if options[:shipping_address]
          post[:paymentRequest][:deliveryAddress] = address_hash(options[:shipping_address])
        end

        commit('Payment.authorise', post)
      end

      def capture(money, authorization, options = {})
        requires!(options, :order_id)

        post = {}
        post[:modificationRequest] = modification_request(authorization, options)
        post[:modificationRequest][:modificationAmount] = amount_hash(money, options[:currency])

        commit('Payment.capture', post)
      end

      def refund(money, authorization, options = {})
        requires!(options, :order_id)

        post = {}
        post[:modificationRequest] = modification_request(authorization, options)
        post[:modificationRequest][:modificationAmount] = amount_hash(money, options[:currency])

        commit('Payment.refund', post)
      end

      def void(identification, options = {})
        requires!(options, :order_id)

        post = {}
        post[:modificationRequest] = modification_request(identification, options)

        commit('Payment.cancel', post)
      end

      def verify(creditcard, options = {})
        authorize(0, creditcard, options)
      end

      private

      def commit(action, post)
        request = post_data(flatten_hash(post.merge(:action => action)))
        raw_response = ssl_post(url, request, headers)
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          test: test?,
          authorization: response['pspReference']
        )

      rescue ResponseError => e
        case e.response.code
        when '401'
          return Response.new(false, 'Invalid credentials', {}, :test => test?)
        when '500'
          if e.response.body.split(' ')[0] == 'validation'
            return Response.new(false, e.response.body.split(' ', 3)[2], {}, :test => test?)
          end
        end
        raise
      end

      def flatten_hash(hash, prefix = nil)
        flat_hash = {}
        hash.each_pair do |key, val|
          conc_key = prefix.nil? ? key : "#{prefix}.#{key}"
          if val.is_a?(Hash)
            flat_hash.merge!(flatten_hash(val, conc_key))
          else
            flat_hash[conc_key] = val
          end
        end
        flat_hash
      end

      def headers
        {
          'Authorization' => 'Basic ' + Base64.encode64("ws@Company.#{@options[:company]}:#{@options[:password]}").strip
        }
      end

      def parse(response)
        Hash[
          response.split('&').map do |x|
            key, val = x.split('=', 2)
            [key.split('.').last, CGI.unescape(val)]
          end
        ]
      end

      def post_data(data)
        data.map do |key, val|
          "#{key}=#{CGI.escape(val.to_s)}"
        end.reduce do |x, y|
          "#{x}&#{y}"
        end
      end

      def message_from(response)
        return response['resultCode'] if response.has_key?('resultCode') # Payment request
        return response['response'] if response['response'] # Modification request
        "Failure" # Negative fallback in case of error
      end

      def success_from(response)
        return true if response.has_key?('authCode')

        successful_responses = %w([capture-received] [cancel-received] [refund-received])
        successful_responses.include?(response['response'])
      end

      def url
        test? ? self.test_url : self.live_url
      end

      def address_hash(address)
        full_address = "#{address[:address1]} #{address[:address2]}"

        {
          :city              => address[:city],
          :street            => full_address.split(/\s+/).keep_if { |x| x !~ /\d/ }.join(' '),
          :houseNumberOrName => full_address.split(/\s+/).keep_if { |x| x =~ /\d/ }.join(' '),
          :postalCode        => address[:zip],
          :stateOrProvince   => address[:state],
          :country           => address[:country]
        }
      end

      def amount_hash(money, currency)
        {
          :currency => (currency || currency(money)),
          :value    => amount(money)
        }
      end

      def credit_card_hash(creditcard)
        {
          :cvc         => creditcard.verification_value,
          :expiryMonth => format(creditcard.month, :two_digits),
          :expiryYear  => format(creditcard.year, :four_digits),
          :holderName  => creditcard.name,
          :number      => creditcard.number
        }
      end

      def modification_request(reference, options)
        {
          :merchantAccount    => @options[:merchant],
          :originalReference  => reference
        }.keep_if { |_, v| v }
      end

      def payment_request(money, options)
        {
          :merchantAccount  => @options[:merchant],
          :reference        => options[:order_id],
          :shopperEmail     => options[:email],
          :shopperIP        => options[:ip],
          :shopperReference => options[:customer]
        }.keep_if { |_, v| v }
      end
    end
  end
end
