require File.dirname(__FILE__) + '/currency.rb'
require File.dirname(__FILE__) + '/country.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayVector
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          
          # Replace with the real mapping
          mapping :account, "MerchantID"
          mapping :order, 'OrderID'
          mapping :currency, 'CurrencyCode'
          mapping :transaction_type, 'TransactionType'
          
          mapping :customer, :email => 'EmailAddress',
                             :phone => 'PhoneNumber'

          mapping :billing_address, :city     => 'City',
                                    :address1 => 'Address1',
                                    :address2 => 'Address2',
                                    :state    => 'State',
                                    :zip      => 'PostCode',
                                    :country  => 'CountryCode'

          mapping :notify_url, 'ServerResultURL'
          mapping :return_url, 'CallbackURL'
          mapping :description, 'OrderDescription'
          
           # Fetches the md5secret and adds MERCHANT_ID and API TYPE to the form
          def initialize(order, account, options = {})
            #store merchant password and the preSharedKey as private variables so they aren't added to the form
            @merchant_password = options.delete(:credential2)
            @pre_shared_key = options.delete(:credential3)
            #currency is given as 3 char code - so convert it to ISO code
            options[:currency] = convert_currency_short_to_ISO_code(options[:currency])
            order = order.to_s
            options.each do |key, option|
              options[key] = option.to_s
            end
            super

            add_field("OrderDescription", "ActiveMerchant Order " + order)
            if(options.has_key?(:amount))
              add_field("Amount", minor_currency_from_major(options[:amount], options[:currency]))
            end

            transaction_date_time
            populate_fields_with_defaults
          end
          
          def minor_currency_from_major(amount, currency_iso_code)
            exponent = ActiveMerchant::Billing::Integrations::PayVector::ISOCurrencies::get_exponent_from_ISO_code(currency_iso_code)
            amount = amount.to_f
            amount *= 10**exponent
            return amount.to_i.to_s
          end

          #PayVector requires country ISO code, so convert the given 2 char code
          def billing_address(params={})
            super
            add_field('CountryCode', ActiveMerchant::Billing::Integrations::PayVector::ISOCountries::get_ISO_code_from_2_digit_short(@fields['CountryCode']))
          end
          
          #Concat first and last names
          def customer(params={})
            add_field(mappings[:customer][:email], params[:email])
            add_field(mappings[:customer][:phone], params[:phone])
            add_field('CustomerName', "#{params[:first_name]} #{params[:last_name]}")
          end
          
          def convert_currency_short_to_ISO_code(currencyCode)
            if(currencyCode.nil?)
              currencyCode = "GBP"
            end
            return ActiveMerchant::Billing::Integrations::PayVector::ISOCurrencies::get_ISO_code_from_short(currencyCode)
          end
          
          def form_fields
            @fields = @fields.merge( {"HashDigest" => generate_hash_digest} )
          end
          
          def generate_hash_digest          
            stringToHash = "PreSharedKey=#{@pre_shared_key}" +
            "&MerchantID=" + @fields["MerchantID"] +
            "&Password=#{@merchant_password}" +
            "&Amount=" + @fields["Amount"] +
            "&CurrencyCode=" + @fields["CurrencyCode"] +
            "&EchoAVSCheckResult=true" +
            "&EchoCV2CheckResult=true" +
            "&EchoThreeDSecureAuthenticationCheckResult=true" +
            "&EchoCardType=true" +
            "&OrderID=" + @fields["OrderID"] +
            "&TransactionType=" + @fields["TransactionType"] +
            "&TransactionDateTime=" + @fields["TransactionDateTime"] +
            "&CallbackURL=" + @fields["CallbackURL"] +
            "&OrderDescription=" + @fields["OrderDescription"] +
            "&CustomerName=" + @fields["CustomerName"] +
            "&Address1=" + @fields["Address1"] +
            "&Address2=" + @fields["Address2"] +
            "&Address3=" +
            "&Address4=" +
            "&City=" + @fields["City"] +
            "&State=" + @fields["State"] +
            "&PostCode=" + @fields["PostCode"] +
            "&CountryCode=" + @fields["CountryCode"] +
            "&EmailAddress=" + @fields["EmailAddress"] +
            "&PhoneNumber=" + @fields["PhoneNumber"] +
            "&EmailAddressEditable=true" +
            "&PhoneNumberEditable=true" +
            "&CV2Mandatory=true" +
            "&Address1Mandatory=true" +
            "&CityMandatory=true" +
            "&PostCodeMandatory=true" +
            "&StateMandatory=true" +
            "&CountryMandatory=true" +
            "&ResultDeliveryMethod=" + @fields["ResultDeliveryMethod"] +
            "&ServerResultURL=" + @fields["ServerResultURL"] +
            "&PaymentFormDisplaysResult=" +
            "&ServerResultURLCookieVariables=" +
            "&ServerResultURLFormVariables=" +
            "&ServerResultURLQueryStringVariables="

            return Digest::SHA1.hexdigest stringToHash
          end

          def transaction_date_time
            add_field('TransactionDateTime', Time.now.strftime("%Y-%m-%d %H:%M:%S %:z"))
          end
          
          private
          
          def populate_fields_with_defaults
            default_blank_fields = ["MerchantID", "Amount", "CurrencyCode", "OrderID",
              "TransactionDateTime", "CallbackURL", "OrderDescription", "CustomerName", "Address1", "Address2", "Address3", "Address4", "City",
              "State", "PostCode", "CountryCode", "EmailAddress", "PhoneNumber", "ServerResultURL",
              "PaymentFormDisplaysResult", "ServerResultURLCookieVariables", "ServerResultURLFormVariables", "ServerResultURLQueryStringVariables"]

            default_blank_fields.each do |field|
              if(!@fields.has_key?(field))
                @fields[field] = ""
              end
            end
            
            default_true_fields = ["EchoAVSCheckResult", "EchoCV2CheckResult", "EchoThreeDSecureAuthenticationCheckResult", "EchoCardType", "CV2Mandatory", "Address1Mandatory",
              "CityMandatory", "PostCodeMandatory", "StateMandatory", "CountryMandatory", "EmailAddressEditable", "PhoneNumberEditable", ]
              
            default_true_fields.each do |field|
              if(!@fields.has_key?(field))
                @fields[field] = "true"
              end
            end
            
            if(!@fields.has_key?("ResultDeliveryMethod"))
              @fields["ResultDeliveryMethod"] = "POST"
            end
            if(!@fields.has_key?("TransactionType"))
              @fields["TransactionType"] = "SALE"
            end
            
          end
        end
      end
    end
  end
end
