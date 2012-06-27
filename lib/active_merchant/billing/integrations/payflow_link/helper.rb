module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayflowLink
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include PostsData

          def initialize(order, account, options = {})
            super
            add_field('login', account)
            add_field('echodata', 'True')
            add_field('user2', self.test?)
            add_field('invoice', order)
            add_field('vendor', account)
            add_field('user', options[:credential4].presence || account)
            add_field('trxtype', options[:transaction_type] || 'S')
          end

          mapping :account, 'login'
          mapping :credential2, 'pwd'
          mapping :credential3, 'partner'
          mapping :order, 'user1'
          mapping :description, 'description'

          mapping :amount, 'amt'


          mapping :billing_address,  :city    => 'city',
                                     :address => 'address',
                                     :state   => 'state',
                                     :zip     => 'zip',
                                     :country => 'country',
                                     :phone   => 'phone',
                                     :name    => 'name'

          mapping :customer, :name => 'name'

          def customer(params = {})
            add_field(mappings[:customer][:name], [params.delete(:first_name), params.delete(:last_name)].compact.join(' '))
          end

          def billing_address(params = {})
            # Get the country code in the correct format
            # Use what we were given if we can't find anything
            country_code = lookup_country_code(params.delete(:country))
            add_field(mappings[:billing_address][:country], country_code)

            add_field(mappings[:billing_address][:address], [params.delete(:address1), params.delete(:address2)].compact.join(' '))

            province_code = params.delete(:state)
            add_field(mappings[:billing_address][:state], province_code.blank? ? 'N/A' : province_code.upcase)

            # Everything else
            params.each do |k, v|
              field = mappings[:billing_address][k]
              add_field(field, v) unless field.nil?
            end
          end

          def form_fields
            token, token_id = request_secure_token

            {"securetoken" => token, "securetokenid" => token_id, "mode" => test? ? "test" : "live"}
          end

          private

          def secure_token_id
            @secure_token_id ||= Utils.generate_unique_id
          end

          def secure_token_url
            test? ? "https://pilot-payflowpro.paypal.com" : "https://payflowpro.paypal.com"
          end

          def request_secure_token
            @fields["securetokenid"] = secure_token_id
            @fields["createsecuretoken"] = "Y"

            fields = @fields.collect {|key, value| "#{key}[#{value.length}]=#{value}" }.join("&")

            response = ssl_post(secure_token_url, fields)

            parse_response(response)
          end

          def parse_response(response)
            response = response.split("&").inject({}) do |hash, param|
              key, value = param.split("=")
              hash[key] = value
              hash
            end

            [response['SECURETOKEN'], response['SECURETOKENID']] if response['RESPMSG'] && response['RESPMSG'].downcase == "approved"
          end
        end
      end
    end
  end
end
