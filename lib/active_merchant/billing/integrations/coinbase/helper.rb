module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Coinbase
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          # account should be a Coinbase API key; see https://coinbase.com/account/integrations
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
