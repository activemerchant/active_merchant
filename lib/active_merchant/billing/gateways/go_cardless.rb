require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GoCardlessGateway < ActiveMerchant::Billing::Gateway
      API_VERSION = '2015-07-06'.freeze

      self.test_url = 'https://api-sandbox.gocardless.com'
      self.live_url = 'https://api.gocardless.com'
      self.default_currency = 'EUR'

      def initialize(options = {})
        requires!(options, :access_token)
        super
      end

      def purchase(money, token, options = {})
        post = {
          payments: {
            amount: money,
            currency: options[:currency] || currency(money),
            description: options[:description],
            links: {
              mandate: token
            }
          }
        }

        commit(:post, '/payments', post, options)
      end

      def store(customer_attributes, bank_account, options = {})
        res = nil
        MultiResponse.run do |r|
          r.process { res = commit(:post, '/customers', customer_params(customer_attributes, options)) }
          if res.success?
            r.process { res = create_bank_account(res.params['customers']['id'], bank_account, options) }
          end
          if res.success?
            r.process { create_mandate(res.params['customer_bank_accounts']['id']) }
          end
        end
      end

      def update(customer_id, customer_attributes, bank_account, options = {})
        res = nil
        MultiResponse.run do |r|
          r.process { res = commit(:put, "/customers/#{customer_id}", customer_params(customer_attributes, options)) }
          if res.success?
            r.process { res = create_bank_account(res.params['customers']['id'], bank_account, options) }
          end
          if res.success?
            r.process { create_mandate(res.params['customer_bank_accounts']['id']) }
          end
        end
      end

      def unstore(customer_id, options = {})
        commit(:delete, "/customers/#{customer_id}", nil, options)
      end

      def cancel_mandate(mandate, options = {})
        commit(:post, "/mandates/#{mandate}/actions/cancel", options)
      end

      def refund(money, identification, options = {})
        res = nil
        money_in_cents = money.respond_to?(:cents) ? money.cents : money.to_i
        total_amount_confirmation = money_in_cents

        MultiResponse.run do |r|
          r.process { res = commit(:get, "/refunds?payment=#{identification}", nil, options) }

          if res.success?
            res.params['refunds'].each do |refund|
              r.process { res = commit(:get, "/refunds/#{refund['id']}", nil, options) }

              if res.success?
                total_amount_confirmation += res.params['refunds']['amount']
              end
            end

            r.process do
              refund_params = {
                refunds: {
                  amount: money_in_cents,
                  total_amount_confirmation: total_amount_confirmation,
                  links: {
                    payment: identification
                  }
                }
              }

              commit(:post, '/refunds', refund_params, options)
            end
          end
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Bearer ).[^\\\r]+), '\1[FILTERED]').
          gsub(%r((\\"danish_identity_number\\":).[^,}]+), '\1[FILTERED]').
          gsub(%r((\\"swedish_identity_number\\":).[^,}]+), '\1[FILTERED]').
          gsub(%r((\\"iban\\":).[^,}]+), '\1[FILTERED]').
          gsub(%r((\\"bank_code\\":).[^,}]+), '\1[FILTERED]').
          gsub(%r((\\"branch_code\\":).[^,}]+), '\1[FILTERED]').
          gsub(%r((\\"account_number\\":).[^,}]+), '\1[FILTERED]')
      end

      private

      def test?
        return true if @options[:access_token].nil?

        @options[:access_token].start_with?('sandbox_')
      end

      def url
        test? ? test_url : live_url
      end

      def parse(response)
        JSON.parse(response || '{}')
      end

      def commit(method, action, params, options={})
        begin
          response = parse(
            ssl_request(
              method,
              (url + action),
              params ? params.to_json : nil,
              headers(options)
            )
          )
        rescue ResponseError => e
          response = parse(e.response.body)
        end

        return Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response, params),
          test: test?
        )
      rescue JSON::ParserError
        return unparsable_response(response)
      end

      def success_from(response)
        (!response['error'])
      end

      def message_from(response)
        (response['error'] ? response['error']['message'] : 'Success')
      end

      def authorization_from(response, params)
        response['payments']['id'] if response['payments']
      end

      def unparsable_response(raw_response)
        message = 'Invalid JSON response received from GoCardless. Please contact GoCardless support if you continue to receive this message.'
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        Response.new(false, message)
      end

      def headers(options)
        {
          'Content-Type'       => 'application/json',
          'Accept'             => 'application/json',
          'User-Agent'         => "ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          'Authorization'      => "Bearer #{@options[:access_token]}",
          'GoCardless-Version' => API_VERSION
        }.tap do |h|
          h['Idempotency-Key'] = options[:order_id] if options[:order_id]
        end
      end

      def customer_params(customer_attributes, options)
        post = {
          customers: {
            "email": customer_attributes['email'],
            "given_name": customer_attributes['first_name'],
            "family_name": customer_attributes['last_name'],
            "phone_number": customer_attributes['phone'],
            "danish_identity_number": customer_attributes['danish_identity_number'],
            "swedish_identity_number": customer_attributes['swedish_identity_number']
          }
        }
        if options[:billing_address]
          post[:customers]["address_line1"] = options[:billing_address][:address1]
          post[:customers]["address_line2"] = options[:billing_address][:address2]
          post[:customers]["city"] = options[:billing_address][:city]
          post[:customers]["region"] = options[:billing_address][:state]
          post[:customers]["postal_code"] = options[:billing_address][:zip]
          post[:customers]["country_code"] = options[:billing_address][:country]
        end
        post
      end

      def create_bank_account(customer_id, bank_account, opts)
        post = {
          customer_bank_accounts: {
            account_holder_name: "#{bank_account.first_name} #{bank_account.last_name}",
            links: {
              "customer": customer_id
            },
            currency: opts[:currency],
            country_code: opts.dig(:billing_address, :country)
          }
        }
        if bank_account.iban.present?
          post[:customer_bank_accounts]['iban'] = bank_account.iban
        else
          post[:customer_bank_accounts]['bank_code'] = bank_account.routing_number.presence || nil
          post[:customer_bank_accounts]['branch_code'] = bank_account.branch_code.presence || nil
          post[:customer_bank_accounts]['account_number'] = bank_account.account_number
        end
        commit(:post, '/customer_bank_accounts', post)
      end

      def create_mandate(bank_account_id)
        post = {
          "mandates": {
            "links": {
              "customer_bank_account": bank_account_id
            }
          }
        }
        commit(:post, '/mandates', post)
      end
    end
  end
end
