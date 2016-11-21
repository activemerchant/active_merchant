module ActiveMerchant
  module Billing
    module MastercardGateway

      def initialize(options={})
        requires!(options, :userid, :password)
        super
      end

      def purchase(amount, payment_method, options={})
        MultiResponse.run do |r|
          r.process { authorize(amount, payment_method, options) }
          r.process { capture(amount, r.authorization, options) }
        end
      end

      def authorize(amount, payment_method, options={})
        post = new_post
        add_invoice(post, amount, options)
        add_reference(post, *new_authorization)
        add_payment_method(post, payment_method)
        add_customer_data(post, payment_method, options)
        add_3dsecure_id(post, options)

        commit('authorize', post)
      end

      def capture(amount, authorization, options={})
        post = new_post
        add_invoice(post, amount, options, :transaction)
        add_reference(post, *next_authorization(authorization))
        add_customer_data(post, nil, options)
        add_3dsecure_id(post, options)

        commit('capture', post)
      end

      def refund(amount, authorization, options={})
        post = new_post
        add_invoice(post, amount, options, :transaction)
        add_reference(post, *next_authorization(authorization))
        add_customer_data(post, nil, options)

        commit('refund', post)
      end

      def void(authorization, options={})
        post = new_post
        add_reference(post, *next_authorization(authorization), :targetTransactionId)

        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def verify_credentials
        url = build_url(SecureRandom.uuid, "nonexistent")
        begin
          ssl_get(url, headers)
        rescue ResponseError => e
          return false if e.response.code.to_i == 401
        end

        true
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic ).*\\r\\n), '\1[FILTERED]').
          gsub(%r(("number"?\\?":"?\\?")\d*), '\1[FILTERED]').
          gsub(%r(("securityCode"?\\?":"?\\?")\d*), '\1[FILTERED]')
      end

      private
      def new_post
        {
          order: {},
          sourceOfFunds: {
            provided: {
              card: {
              }
            }
          },
          customer: {},
          billing: {},
          device: {},
          shipping: {},
          transaction: {},
        }
      end

      def add_invoice(post, amount, options, node=:order)
        post[node][:amount] = amount(amount)
        post[node][:currency] = (options[:currency] || currency(amount))
      end

      def add_reference(post, orderid, transactionid, transaction_reference, reference_key=:reference)
        post[:orderid] = orderid
        post[:transactionid] = transactionid
        post[:transaction][reference_key] = transaction_reference if transaction_reference
      end

      def add_payment_method(post, payment_method)
        card = {}
        card[:expiry] = {}
        card[:number] = payment_method.number
        card[:securityCode] = payment_method.verification_value
        card[:expiry][:year] = format(payment_method.year, :two_digits)
        card[:expiry][:month] = format(payment_method.month, :two_digits)

        post[:sourceOfFunds][:type] = 'CARD'
        post[:sourceOfFunds][:provided][:card].merge!(card)
      end

      def add_customer_data(post, payment_method, options)
        billing = {}
        shipping = {}
        customer = {}
        device = {}

        customer[:firstName] = payment_method.first_name if payment_method
        customer[:lastName] = payment_method.last_name if payment_method
        customer[:email] = options[:email] if options[:email]
        device[:ipAddress] = options[:ip] if options[:ip]

        if (billing_address = options[:billing_address])
          billing[:address] = {}
          billing[:address][:street]        = billing_address[:address1]
          billing[:address][:street2]       = billing_address[:address2]
          billing[:address][:city]          = billing_address[:city]
          billing[:address][:stateProvince] = billing_address[:state]
          billing[:address][:postcodeZip]   = billing_address[:zip]
          billing[:address][:country]       = country_code(billing_address[:country])
          customer[:phone]                  = billing_address[:phone]
        end

        if (shipping_address = options[:shipping_address])
          shipping[:address] = {}
          shipping[:address][:street]        = shipping_address[:address1]
          shipping[:address][:street2]       = shipping_address[:address2]
          shipping[:address][:city]          = shipping_address[:city]
          shipping[:address][:stateProvince] = shipping_address[:state]
          shipping[:address][:postcodeZip]   = shipping_address[:zip]
          shipping[:address][:shipcountry]   = country_code(shipping_address[:country])

          first_name, last_name = split_names(shipping_address[:name])
          shipping[:firstName]  = first_name if first_name
          shipping[:lastName]   = last_name if last_name
        end
        post[:billing].merge!(billing)
        post[:shipping].merge!(shipping)
        post[:device].merge!(device)
        post[:customer].merge!(customer)
      end

      def add_3dsecure_id(post, options)
        return unless options[:threed_secure_id]
        post.merge!({"3DSecureId" => options[:threed_secure_id]})
      end

      def country_code(country)
        if country
          country = ActiveMerchant::Country.find(country)
          country.code(:alpha3).value
        end
      rescue InvalidCountryCodeError
      end

      def headers
        {
          'Authorization' => 'Basic ' + Base64.encode64("merchant.#{@options[:userid]}:#{@options[:password]}").strip.delete("\r\n"),
          'Content-Type' => 'application/json',
        }
      end

      def commit(action, post)
        url = build_url(post.delete(:orderid), post.delete(:transactionid))
        post[:apiOperation] = action.upcase
        begin
          raw = parse(ssl_request(:put, url, build_request(post), headers))
        rescue ResponseError => e
          raw = parse(e.response.body)
        end
        succeeded = success_from(raw)
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          :authorization => authorization_from(post, raw),
          :test => test?
        )
      end

      def build_url(orderid, transactionid)
        "#{base_url}merchant/#{@options[:userid]}/order/#{orderid}/transaction/#{transactionid}"
      end

      def base_url
        if test?
          @options[:region] == 'asia_pacific' ? test_ap_url : test_na_url
        else
          @options[:region] == 'asia_pacific' ? live_ap_url : live_na_url
        end
      end

      def build_request(post = {})
        post.to_json
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        response['result'] == "SUCCESS"
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        else
          [
            response['result'],
            response['response'] && response['response']['gatewayCode'],
            response['error'] && response['error']['cause'],
            response['error'] && response['error']['explanation']
          ].compact.join(' - ')
        end
      end

      def authorization_from(request, response)
        [response['order']['id'], response['transaction']['id']].join('|') if response['order']
      end

      def split_authorization(authorization)
        authorization.split('|')
      end

      def new_authorization
        # Must be unique within a merchant id.
        orderid = SecureRandom.uuid

        # Must be unique within an order id.
        transactionid = '1'

        # New transactions have no previous reference.
        transaction_reference = nil
        [orderid, transactionid, transaction_reference]
      end

      def next_authorization(authorization)
        orderid, prev_transactionid = split_authorization(authorization)
        next_transactionid = SecureRandom.uuid
        [orderid, next_transactionid, prev_transactionid]
      end

    end
  end
end
