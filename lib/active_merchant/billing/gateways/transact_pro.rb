module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information visit {Transact Pro Services}[https://www.transactpro.lv/business/]
    #
    # This gateway was formerly associated with www.1stpayments.net
    #
    # Written by Piers Chambers (Varyonic.com)
    class TransactProGateway < Gateway
      self.test_url = 'https://gw2sandbox.tpro.lv:8443/gw2test/gwprocessor2.php'
      self.live_url = 'https://www2.1stpayments.net/gwprocessor2.php'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.transactpro.lv/business/online-payments-acceptance'
      self.display_name = 'Transact Pro'

      def initialize(options={})
        requires!(options, :guid, :password, :terminal)
        super
      end

      def purchase(amount, payment, options={})
        post = PostData.new
        add_invoice(post, amount, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)
        add_credentials(post)
        post[:rs] = @options[:terminal]

        MultiResponse.run do |r|
          r.process { commit('init', post) }
          r.process do
            post = PostData.new
            post[:init_transaction_id] = r.authorization
            add_payment_cc(post, payment)
            post[:f_extended] = '4'

            commit('charge', post, amount)
          end
        end
      end

      def authorize(amount, payment, options={})
        post = PostData.new
        add_invoice(post, amount, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)
        add_credentials(post)
        post[:rs] = @options[:terminal]

        MultiResponse.run do |r|
          r.process { commit('init_dms', post) }
          r.process do
            post = PostData.new
            post[:init_transaction_id] = r.authorization
            add_payment_cc(post, payment)
            post[:f_extended] = '4'

            commit('make_hold', post, amount)
          end
        end
      end

      def capture(amount, authorization, options={})
        identifier, original_amount = split_authorization(authorization)
        raise ArgumentError.new("Partial capture is not supported, and #{amount.inspect} != #{original_amount.inspect}") if amount && (amount != original_amount)

        post = PostData.new
        add_credentials(post)
        post[:init_transaction_id] = identifier
        post[:f_extended] = '4'

        commit('charge_hold', post, original_amount)
      end

      def refund(amount, authorization, options={})
        identifier, original_amount = split_authorization(authorization)

        post = PostData.new
        add_credentials(post, :account_guid)
        post[:init_transaction_id] = identifier
        post[:amount_to_refund] = amount(amount || original_amount)

        commit('refund', post)
      end

      def void(authorization, options={})
        identifier, amount = split_authorization(authorization)

        post = PostData.new
        add_credentials(post, :account_guid)
        post[:init_transaction_id] = identifier
        post[:amount_to_refund] = amount(amount)
        commit('cancel_dms', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def add_customer_data(post, options)
        post[:email] = (options[:email] || 'noone@example.com')
        post[:user_ip] = (options[:ip] || '127.0.0.1')
      end

      def add_address(post, creditcard, options)
        if address = options[:billing_address]
          post[:street]  = address[:address1].to_s
          post[:city]    = address[:city].to_s
          post[:state]   = (address[:state].blank? ? 'NA' : address[:state].to_s)
          post[:zip]     = address[:zip].to_s
          post[:country] = address[:country].to_s
          post[:phone]   = (address[:phone].to_s.gsub(/[^0-9]/, '') || '0000000')
        end

        if address = options[:shipping_address]
          post[:shipping_name]    = "#{address.first_name} #{address.last_name}"
          post[:shipping_street]  = address[:address1].to_s
          post[:shipping_phone]   = address[:phone].to_s
          post[:shipping_zip]     = address[:zip].to_s
          post[:shipping_city]    = address[:city].to_s
          post[:shipping_country] = address[:country].to_s
          post[:shipping_state]   = (address[:state].blank? ? 'NA' : address[:state].to_s)
          post[:shipping_email]   = (options[:email] || 'noone@example.com')
        end
      end

      def add_invoice(post, money, options)
        post[:merchant_transaction_id] = options[:order_id] if options[:order_id]
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:description] = options[:description]
        post[:merchant_site_url] = options[:merchant]
      end

      def add_payment(post, payment)
        post[:name_on_card] = "#{payment.first_name} #{payment.last_name}"
        post[:card_bin] = payment.first_digits
      end

      def add_payment_cc(post, credit_card)
        post[:cc] = credit_card.number
        post[:cvv] = credit_card.verification_value if credit_card.verification_value?
        year  = sprintf('%.4i', credit_card.year)
        month = sprintf('%.2i', credit_card.month)
        post[:expire] = "#{month}/#{year[2..3]}"
      end

      def add_credentials(post, key=:guid)
        post[key] = @options[:guid]
        post[:pwd] = Digest::SHA1.hexdigest(@options[:password])
      end

      def parse(body)
        if /^ID:/.match?(body)
          body.split('~').reduce(Hash.new) { |h, v|
            m = v.match('(.*?):(.*)')
            h.merge!(m[1].underscore.to_sym => m[2])
          }
        elsif (m = body.match('(.*?):(.*)'))
          m[1] == 'OK' ?
            { status: 'success', id: m[2] } :
            { status: 'failure', message: m[2] }
        else
          Hash[status: body]
        end
      end

      def commit(action, parameters, amount=nil)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(parameters, response, amount),
          test: test?
        )
      end

      def authorization_from(parameters, response, amount)
        identifier = (response[:id] || parameters[:init_transaction_id])
        authorization = [identifier]
        authorization << amount if amount
        authorization.join('|')
      end

      def split_authorization(authorization)
        if /|/.match?(authorization)
          identifier, amount = authorization.split('|')
          [identifier, amount.to_i]
        else
          authorization
        end
      end

      def success_from(response)
        (response[:status] =~ /success/i || response[:status] =~ /ok/i)
      end

      def message_from(response)
        (response[:message] || response[:status])
      end

      def post_data(action, parameters = {})
        parameters[:a] = action
        parameters.to_s
      end
    end
  end
end
