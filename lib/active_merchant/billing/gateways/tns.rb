module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TnsGateway < Gateway
      self.display_name = 'TNS'
      self.homepage_url = 'http://www.tnsi.com/'

      # Testing is partitioned by account.
      self.live_url = 'https://secure.na.tnspayments.com/api/rest/version/22/'

      self.supported_countries = %w(AR AU BR FR DE HK MX NZ SG GB US)

      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro, :laser]

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
        add_customer_data(post, options)

        commit('authorize', post)
      end

      def capture(amount, authorization, options={})
        post = new_post
        add_invoice(post, amount, options, :transaction)
        add_reference(post, *next_authorization(authorization))
        add_customer_data(post, options)

        commit('capture', post)
      end

      def refund(amount, authorization, options={})
        post = new_post
        add_invoice(post, amount, options, :transaction)
        add_reference(post, *next_authorization(authorization))
        add_customer_data(post, options)

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

      def add_customer_data(post, options)
        billing = {}
        shipping = {}
        customer = {}
        if(billing_address = (options[:billing_address] || options[:address]))
          billing[:address] = {}
          billing[:address][:street]        = billing_address[:address1]
          billing[:address][:street2]       = billing_address[:address2]
          billing[:address][:city]          = billing_address[:city]
          billing[:address][:stateProvince] = billing_address[:state]
          billing[:address][:postcodeZip]   = billing_address[:zip]
          billing[:address][:country]       = billing_address[:country]
          billing[:phone]                   = billing_address[:phone]

          customer[:email]                  = options[:email] if options[:email]
          customer[:ipaddress]              = options[:ip] if options[:ip]
        end

        if(shipping_address = options[:shipping_address])
          shipping[:address] = {}
          shipping[:address][:street]        = shipping_address[:address1]
          shipping[:address][:street2]       = shipping_address[:address2]
          shipping[:address][:city]          = shipping_address[:city]
          shipping[:address][:stateProvince] = shipping_address[:state]
          shipping[:address][:postcodeZip]   = shipping_address[:zip]
          shipping[:address][:shipcountry]   = shipping_address[:country]

          last_name, first_middle_names = split_name(shipping_address[:name])
          shipping[:firstName]  = first_middle_names if first_middle_names
          shipping[:lastName]   = last_name if last_name
        end
        post[:billing].merge!(billing)
        post[:shipping].merge!(shipping)
        post[:customer].merge!(customer)
      end

      def commit(action, post)
        url = build_url(post.delete(:orderid), post.delete(:transactionid))
        headers = {
          'Authorization' => 'Basic ' + Base64.encode64("merchant.#{@options[:userid]}:#{@options[:password]}").strip.delete("\r\n"),
          'Content-Type' => 'application/json',
        }
        post[:apiOperation] = action.upcase
        raw = parse(ssl_request(:put, url, build_request(post), headers))

        succeeded = success_from(raw['result'])
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          :authorization => authorization_from(post, raw),
          :test => test?
        )
      end

      def build_url(orderid, transactionid)
        "#{live_url}merchant/#{@options[:userid]}/order/#{orderid}/transaction/#{transactionid}"
      end

      def build_request(post = {})
        post.to_json
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        response == 'SUCCESS'
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

      def split_name(full_name)
        return nil unless full_name
        names = full_name.split
        [names.pop, names.join(' ')]
      end
    end
  end
end
