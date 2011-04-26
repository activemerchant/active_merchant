module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module DirecPay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account,  'MID'
          mapping :order,    'Merchant Order No'
          mapping :amount,   'Amount'
          mapping :currency, 'Currency'
          mapping :country,  'Country'
          
          mapping :billing_address,  :city     => 'custCity',
                                     :address1 => 'custAddress',
                                     :state    => 'custState',
                                     :zip      => 'custPinCode',
                                     :country  => 'custCountry',
                                     :phone    => 'custMobileNo'

          mapping :shipping_address, :name     => 'deliveryName',
                                     :city     => 'deliveryCity',
                                     :address1 => 'deliveryAddress',
                                     :state    => 'deliveryState',
                                     :zip      => 'deliveryPinCode',
                                     :country  => 'deliveryCountry',
                                     :phone    => 'deliveryMobileNo'

          mapping :customer, :name  => 'custName',
                             :email => 'custEmailId'

          mapping :description, 'otherNotes'
          mapping :edit_allowed, 'editAllowed'
          
          mapping :return_url, 'Success URL'
          mapping :failure_url, 'Failure URL'
          
          mapping :operating_mode, 'Operating Mode'
          mapping :other_details, 'Other Details'
          mapping :collaborator, 'Collaborator'
          
          OPERATING_MODE = 'DOM'
          COUNTRY        = 'IND'
          CURRENCY       = 'INR'
          OTHER_DETAILS  = 'NULL'
          EDIT_ALLOWED   = 'Y'
          
          PHONE_CODES = {
            'IN' => '91',
            'US' => '01',
            'CA' => '01'
          }
          
          ENCODED_PARAMS = [ :account, :operating_mode, :country, :currency, :amount, :order, :other_details, :return_url, :failure_url, :collaborator ]
          
          
          def initialize(order, account, options = {})
            super
            collaborator = ActiveMerchant::Billing::Base.integration_mode == :test || options[:test] ? 'TOML' : 'DirecPay'
            add_field(mappings[:collaborator], collaborator)
            add_field(mappings[:country], 'IND')
            add_field(mappings[:operating_mode], OPERATING_MODE)
            add_field(mappings[:other_details], OTHER_DETAILS)
            add_field(mappings[:edit_allowed], EDIT_ALLOWED)
          end
          

          def customer(params = {})
            full_name = "#{params[:first_name]} #{params[:last_name]}"
            add_field(mappings[:customer][:name], full_name)
            add_field(mappings[:customer][:email], params[:email])
          end
          
          # Need to format the amount to have 2 decimal places
          def amount=(money)
            cents = money.respond_to?(:cents) ? money.cents : money
            if money.is_a?(String) or cents.to_i <= 0
              raise ArgumentError, 'money amount must be either a Money object or a positive integer in cents.'
            end
            add_field(mappings[:amount], sprintf("%.2f", cents.to_f/100))
          end
          
          def shipping_address(params = {})
            update_address(:shipping_address, params)
            super(params.dup)
          end
          
          def billing_address(params = {})
            update_address(:billing_address, params)
            super(params.dup)
          end
          
          def form_fields
            add_failure_url
            add_request_parameters
            
            unencoded_parameters
          end
          

          private

          def add_request_parameters
            params = ENCODED_PARAMS.map{ |param| fields[mappings[param]] }
            encoded = encode_value(params.join('|'))
            
            add_field('requestparameter', encoded)
          end
          
          def unencoded_parameters
            params = fields.dup
            # remove all encoded params from exported fields
            ENCODED_PARAMS.each{ |param| params.delete(mappings[param]) }
            # remove all special characters from each field value
            params = params.collect{|name, value| [name, remove_special_characters(value)] }
            Hash[params]
          end
          
          def add_failure_url
            if fields[mappings[:failure_url]].nil?
              add_field(mappings[:failure_url], fields[mappings[:return_url]])
            end
          end
          
          def update_address(address_type, params)
            address = params[:address1]
            address << " #{params[:address2]}" if params[:address2]
            params[:address1] = address
            params[:phone] = normalize_phone_number(params[:phone])
            add_land_line_phone_for(address_type, params)
            
            if address_type == :shipping_address && params[:name].blank?
              add_field(mappings[:shipping_address][:name], fields[mappings[:customer][:name]])
            end
          end
          
          # Split a single phone number into the country code, area code and local number as best as possible
          def add_land_line_phone_for(address_type, params)
            address_field = address_type == :billing_address ? 'custPhoneNo' : 'deliveryPhNo'
            
            if params.has_key?(:phone2)
              phone = normalize_phone_number(params[:phone2])
              phone_country_code, phone_area_code, phone_number = nil
              
              if params[:country] == 'IN' && phone =~ /(91)? *(\d{3}) *(\d{4,})$/
                phone_country_code, phone_area_code, phone_number = $1, $2, $3
              else
                numbers = phone.split(' ')
                case numbers.size
                when 3
                  phone_country_code, phone_area_code, phone_number = numbers
                when 2
                  phone_area_code, phone_number = numbers
                else
                  phone =~ /(\d{3})(\d+)$/
                  phone_area_code, phone_number = $1, $2
                end
              end
              
              add_field("#{address_field}1", phone_country_code || phone_code_for_country(params[:country]) || '91')
              add_field("#{address_field}2", phone_area_code)
              add_field("#{address_field}3", phone_number)
            end
          end
          
          def normalize_phone_number(phone)
            phone.gsub(/[^\d ]+/, '') if phone
          end
          
          # Special characters are NOT allowed while posting transaction parameters on DirecPay system
          def remove_special_characters(string)
            string.gsub(/[~"'&#%]/, '-')
          end
          
          def encode_value(value)
            encoded = ActiveSupport::Base64.encode64s(value)
            string_to_encode = encoded[0, 1] + "T" + encoded[1, encoded.length]
            ActiveSupport::Base64.encode64s(string_to_encode)
          end
          
          def decode_value(value)
            decoded = ActiveSupport::Base64.decode64(value)
            string_to_decode = decoded[0, 1] + decoded[2, decoded.length]
            ActiveSupport::Base64.decode64(string_to_decode)
          end
          
          def phone_code_for_country(country)
            PHONE_CODES[country]
          end
        end
      end
    end
  end
end
