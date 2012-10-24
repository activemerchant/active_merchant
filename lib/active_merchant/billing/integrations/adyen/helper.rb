require 'base64'
require 'stringio'
require 'zlib'
require 'openssl'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Adyen
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          # the values of these fields are concatenated, HMAC digested, Base64 encoded, and sent along with the POST data to make hoodwinkery difficult
          SIGNATURE_FIELDS = [
            :paymentAmount,
            :currencyCode,  
            :shipBeforeDate,
            :merchantReference,
            :skinCode,
            :merchantAccount,
            :sessionValidity,
          ]

          # same as above but for the customer's street address, which is to be separately hashed, as specified by Adyen
          # country should be ISO 3166-1 alpha-2 format, see http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2 )
          ADDRESS_SIGNATURE_FIELDS = %w( billingAddress.street billingAddress.houseNumberOrName billingAddress.city billingAddress.postalCode billingAddress.stateOrProvince billingAddress.country ) 

          def initialize(order, account, options = {})
            super
            add_field('currencyCode',    'USD')
            add_field('shipBeforeDate',  Date.today + 10)
            add_field('skinCode',        'notavalidskincode')
            add_field('shopperLocale',   'en_GB')
            add_field('orderData',       'orderData')
            add_field('sessionValidity', "#{ (Date.today + 10).to_s }T11:00:00Z" )
          end

          # orderData is a string of HTML which is displayed along with the CC form
          # it is GZipped, Base64 encoded, and sent along with the POST data
          def set_order_data(value)
            str = StringIO.new
            gz = Zlib::GzipWriter.new str
            gz.write value
            gz.close
            @order_data = Base64.encode64(str.string()).gsub("\n","")
          end

          def shared_secret(value)
            @shared_secret = value
          end

          def form_fields
            @fields.merge!('merchantSig' => generate_signature)
            @fields.merge!('billingAddressSig' => generate_address_signature) if @billing_address
            @fields.merge!('orderData' => @order_data) if @order_data
            @fields
          end

          def generate_signature_string
            SIGNATURE_FIELDS.map {|key| @fields[key.to_s]} * ""
          end

          def generate_signature
            digest = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA1.new, @shared_secret, generate_signature_string)
            return Base64.encode64(digest).strip
          end

          def generate_address_signature_string
          end
            
          # Replace with the real mapping
          mapping :account, 'merchantAccount'
          mapping :amount, 'paymentAmount'
          mapping :order, 'merchantReference'

          mapping :currencyCode, 'currencyCode'
          mapping :shipBeforeDate, 'shipBeforeDate'
          mapping :skinCode, 'skinCode'
          mapping :shopperLocale, 'shopperLocale'
          mapping :orderData, 'orderData'
          mapping :sessionValidity, 'sessionValidity'

          mapping :customer, :email      => 'shopperEmail'

          mapping :billing_address, :city     => 'billingAddress.city',
                                    :address1 => 'billingAddress.street',
                                    #:address2 => 'billingAddress.????',
                                    :state    => 'billingAddress.stateOrProvince',
                                    :zip      => 'billingAddress.postalCode',
                                    :country  => 'billingAddress.country'

          mapping :notify_url, ''
          mapping :return_url, ''
          mapping :cancel_return_url, ''
          mapping :description, ''
          mapping :tax, ''
          mapping :shipping, ''

        end
      end
    end
  end
end
