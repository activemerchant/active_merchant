module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WorldPay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account, 'instId'
          mapping :amount, 'amount'
          mapping :order, 'cartId'
          mapping :currency, 'currency'

          mapping :customer, :email => 'email',
                             :phone => 'tel'

          mapping :billing_address, :zip => 'postcode',
                                    :country  => 'country'

          mapping :description, 'desc'
          mapping :notify_url, 'MC_callback'
          
          
          # WorldPay supports two different test modes - :always_succeed and :always_fail
          def initialize(order, account, options = {})
            super
            
            if ActiveMerchant::Billing::Base.integration_mode == :test || options[:test]
              test_mode = case options[:test]
              when :always_fail
                101
              when false
                0
              else
                100
              end
              add_field('testMode', test_mode.to_s)
            elsif ActiveMerchant::Billing::Base.integration_mode == :always_succeed
              add_field('testMode', '100')
            elsif ActiveMerchant::Billing::Base.integration_mode == :always_fail
              add_field('testMode', '101')
            end
          end
          
          # WorldPay only supports a single address field so we 
          # have to concat together - lines are separated using &#10;
          def billing_address(params={})
            add_field(mappings[:billing_address][:zip], params[:zip])
            add_field(mappings[:billing_address][:country], lookup_country_code(params[:country]))
            
            address = [params[:address1], params[:address2], params[:city], params[:state]].compact
            add_field('address', address.join('&#10;'))
          end
          
          # WorldPay only supports a single name field so we have to concat
          def customer(params={})
            add_field(mappings[:customer][:email], params[:email])
            add_field(mappings[:customer][:phone], params[:phone])
            add_field('name', "#{params[:first_name]} #{params[:last_name]}")
          end
          
          # Support for a MD5 hash of selected fields to prevent tampering
          # For futher information read the tech note at the address below: 
          # http://support.worldpay.com/kb/integration_guides/junior/integration/help/tech_notes/sjig_tn_009.html
          def encrypt(secret, fields = [:amount, :currency, :account, :order])
            signature_fields = fields.collect{ |field| mappings[field] }
            add_field('signatureFields', signature_fields.join(':'))

            field_values = fields.collect{ |field| form_fields[mappings[field]] }
            signature    = "#{secret}:#{field_values.join(':')}"            
            add_field('signature', Digest::MD5.hexdigest(signature))
          end
          
          # Add a time window for which the payment can be completed. Read the link below for how they work
          # http://support.worldpay.com/kb/integration_guides/junior/integration/help/appendicies/sjig_10100.html
          def valid_from(from_time)
            add_field('authValidFrom', from_time.to_i.to_s + '000')
          end
          
          def valid_to(to_time)
            add_field('authValidTo', to_time.to_i.to_s + '000')
          end
          
          # WorldPay supports the passing of custom parameters prefixed with the following:
          # C_          : These parameters can be used in the response pages hosted on WorldPay's site
          # M_          : These parameters are passed through to the callback script (if enabled)
          # MC_ or CM_  : These parameters are availble both in the response and callback contexts
          def response_params(params={})
            params.each{|k,v| add_field("C_#{k}",v)}
          end
          
          def callback_params(params={})
            params.each{|k,v| add_field("M_#{k}",v)}
          end
          
          def combined_params(params={})
            params.each{|k,v| add_field("MC_#{k}",v)}
          end
        end
      end
    end
  end
end