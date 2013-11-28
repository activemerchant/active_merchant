module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Molpay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include RequiresParameters

          #Currencies supported
          #MYR (Malaysian Ringgit - Malaysia Payment Gateway (Credit Card & local debit payment), Union Pay, Alipay)
          #USD (US Dollar)
          #CNY (Chinese Renminbi)
          #TWD (Taiwan Dollar)
          SUPPORTED_CURRENCIES = %w[MYR USD CNY TWD]

          #Languages supported
          #en English (default)
          #cn Simplified Chinese
          SUPPORTED_LANGS      = %w[en cn]

          attr_reader :amount_in_cents, :merchant_key

          #credential2 = vcode
          #order = orderid
          #amount = total amount
          #currency = currency
          def initialize(order, account, options = {})
            requires!(options, :amount, :currency, :credential2)
            @merchant_key = options[:credential2]
            @amount_in_cents = options[:amount]
            super
          end

          #Check and validate amount
          def amount=(money)
            cents = money.respond_to?(:cents) ? money.cents : money
            if money.is_a?(String) or cents.to_i < 0
              raise ArgumentError, "Money amount must be either a Money object or a positive integer in cents."
            end
            add_field mappings[:amount], sprintf("%.2f", cents.to_f/100)
          end

          #Check supported currency
          def currency(symbol)
            raise ArgumentError, "Unsupported currency" unless SUPPORTED_CURRENCIES.include?(symbol)
            add_field mappings[:currency], symbol
          end

          #Check supported language
          def language(lang)
            raise ArgumentError, "Unsupported language" unless SUPPORTED_LANGS.include?(lang)
            add_field mappings[:language], lang
          end

          #Define customer details
          def customer(params = {})
            add_field(mappings[:customer][:name], "#{params[:first_name]} #{params[:last_name]}")
            add_field(mappings[:customer][:email], params[:email])
            add_field(mappings[:customer][:phone], params[:phone])
          end
					
          #Generate vcodes to ensure data integrity
          def vcodes
            self.generate_vcode
          end

          #Mapping :variable_name form_name&form_id
          mapping :account,       "merchantid"
          mapping :amount,        "amount"
          mapping :currency,      "cur"
          mapping :order,         "orderid"
          mapping :description,   "bill_desc"
          mapping :customer,      :name  => "bill_name",
                                  :email => "bill_email",
                                  :phone => "bill_mobile"
          mapping :language,      "langcode"
          mapping :return_url,    "returnurl"
          mapping :vcode,         "vcode"

          #Protected method
          protected
          
          #generate the vcode
          def generate_vcode
            require 'digest/md5'
	    		
            vcode = fields[mappings[:amount]]
            vcode = vcode + fields[mappings[:account]]
            vcode = vcode + fields[mappings[:order]]
            vcode = vcode + @merchant_key

            add_field mappings[:vcode], Digest::MD5.hexdigest(vcode)
          end
        end
      end
    end
  end
end
