require "digest/sha1"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ipay88
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include RequiresParameters

          # Currencies supported
          #   MYR (Malaysian Ringgit - for all payment methods except China Union Pay and PayPal)
          #   USD (US Dollar - only for PayPal)
          #   CNY (Yuan Renminbi - only for China Union Pay)
          SUPPORTED_CURRENCIES = %w[MYR USD CNY]

          # Languages supported
          #   ISO-8859-1 (English)
          #   UTF-8      (Unicode)
          #   GB2312     (Chinese Simplified)
          #   GD18030    (Chinese Simplified)
          #   BIG5       (Chinese Traditional)
          SUPPORTED_LANGS      = %w[ISO-8859-1 UTF-8 GB2312 GD18030 BIG5]

          # Payment methods supported
          #   8  (Alliance Online Transfer)
          #   10 (AmBank)
          #   21 (China Union Pay)
          #   20 (CIMB Click)
          #   2  (Credit Card MYR)
          #   16 (FPX)
          #   15 (Hong Leong Bank Transfer)
          #   6  (Maybank2u.com)
          #   23 (MEPS Cash)
          #   17 (Mobile Money)
          #   33 (PayPal)
          #   14 (RHB)
          PAYMENT_METHODS      = %w[8 10 21 20 2 16 15 6 23 17 33 14]

          attr_reader :amount_in_cents, :merchant_key

          def initialize(order, account, options = {})
            requires!(options, :amount, :currency, :credential2)
            @merchant_key = options[:credential2]
            @amount_in_cents = options[:amount]
            super
            add_field mappings[:signature], signature
          end

          def amount_in_dollars
            sprintf("%.2f", @amount_in_cents.to_f/100)
          end

          def amount=(money)
            @amount_in_cents = money.respond_to?(:cents) ? money.cents : money
            raise ArgumentError, "amount must be a Money object or an integer" if money.is_a?(String)
            raise ActionViewHelperError, "amount must be greater than $0.00" if @amount_in_cents.to_i <= 0

            add_field mappings[:amount], amount_in_dollars
          end

          def currency(symbol)
            raise ArgumentError, "unsupported currency" unless SUPPORTED_CURRENCIES.include?(symbol)
            add_field mappings[:currency], symbol
          end

          def language(lang)
            raise ArgumentError, "unsupported language" unless SUPPORTED_LANGS.include?(lang)
            add_field mappings[:language], lang
          end

          def payment(pay_method)
            raise ArgumentError, "unsupported payment method" unless PAYMENT_METHODS.include?(pay_method.to_s)
            add_field mappings[:payment], pay_method
          end

          def customer(params = {})
            add_field(mappings[:customer][:name], "#{params[:first_name]} #{params[:last_name]}")
            add_field(mappings[:customer][:email], params[:email])
            add_field(mappings[:customer][:phone], params[:phone])
          end

          def self.sign(str)
            [Digest::SHA1.digest(str)].pack("m").chomp
          end

          def signature
            self.class.sign(self.sig_components)
          end

          mapping :account,     "MerchantCode"
          mapping :amount,      "Amount"
          mapping :currency,    "Currency"
          mapping :order,       "RefNo"
          mapping :description, "ProdDesc"
          mapping :customer, :name  => "UserName",
                             :email => "UserEmail",
                             :phone => "UserContact"
          mapping :remark,      "Remark"
          mapping :language,    "Lang"
          mapping :payment,     "PaymentId"
          mapping :return_url,  "ResponseURL"
          mapping :signature,   "Signature"

          protected

          def sig_components
            components  = [merchant_key]
            components << fields[mappings[:account]]
            components << fields[mappings[:order]]
            components << amount_in_dollars.gsub(/[.,]/, '')
            components << fields[mappings[:currency]]
            components.join
          end
        end
      end
    end
  end
end
