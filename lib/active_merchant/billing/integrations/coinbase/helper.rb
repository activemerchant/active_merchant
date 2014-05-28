module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Coinbase
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          # account should be a Coinbase API key; see https://coinbase.com/account/integrations
          # options[:credential2] should be the corresponding API secret
          def initialize(order_id, account, options)
          	super

          	@order = order_id
          	@account = account
          	@options = options
          end

          mapping :amount, ''

          mapping :order, ''

          mapping :customer, :first_name => '',
                             :last_name  => '',
                             :email      => '',
                             :phone      => ''

          mapping :billing_address, :city     => '',
                                    :address1 => '',
                                    :address2 => '',
                                    :state    => '',
                                    :zip      => '',
                                    :country  => ''

          mapping :notify_url, 'notify_url'
          mapping :return_url, 'return_url'
          mapping :cancel_return_url, 'cancel_return_url'
          mapping :description, ''
          mapping :tax, ''
          mapping :shipping, ''

          def form_fields
            uri = URI.parse(Coinbase.buttoncreate_url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            request = Net::HTTP::Post.new(uri.request_uri)

            title = @options[:description]
            if title.nil?
            	title = "Your Order"
            end

            request.body = {
              'button[name]' => title,
              'button[price_string]' => @options[:amount],
              'button[price_currency_iso]' => @options[:currency],
              'button[custom]' => @order,
              'button[callback_url]' => @fields['notify_url'],
              'button[success_url]' => @fields['return_url'],
              'button[cancel_url]' => @fields['cancel_return_url'],
              'api_key' => @account
            }.to_query

            # Authentication
            nonce = (Time.now.to_f * 1e6).to_i
            hmac_message = nonce.to_s + Coinbase.buttoncreate_url + request.body
            request['ACCESS_KEY'] = @account
            request['ACCESS_SIGNATURE'] = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @options[:credential2], hmac_message)
            request['ACCESS_NONCE'] = nonce.to_s

            data = http.request(request).body
            json = JSON.parse(data)

            if json.nil?
            	raise "Response invalid %s" % data
            end
            unless json['success']
            	raise "JSON error %s" % JSON.pretty_generate(json)
            end

            button = json['button']

            {'id' => button['code']}
          end
        end
      end
    end
  end
end
