require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module YandexMoney
        class Notification < ActiveMerchant::Billing::Integrations::Notification
        
          %w(
            requestDatetime
            action
            md5
            shopId
            shopArticleId
            invoiceId
            orderNumber
            customerNumber
            orderCreatedDatetime
            orderSumAmount
            orderSumCurrencyPaycash
            orderSumBankPaycash
            shopSumAmount
            shopSumCurrencyPaycash
            shopSumBankPaycash
            paymentPayerCode
            paymentType
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :action, :action
          alias_method :amount, :order_sum_amount
          alias_method :currency_code, :order_sum_currency_paycash
          alias_method :currency_bank, :order_sum_bank_paycash
          alias_method :shop_id, :shop_id
          alias_method :yandex_transaction_id, :invoice_id
          alias_method :customer_number, :customer_number

          def status
            case @options[:yandex_money_action]
              when 'paymentAviso' then 'completed'
              when 'checkOrder' then 'pending'
              when 'cancelOrder' then 'canceled'
              else 'unknown'
            end
          end

          def generate_signature
            string = [@options[:yandex_money_action], amount, currency_code, currency_bank, shop_id, yandex_transaction_id, customer_number, @options[:secret]].join(';')
            Digest::MD5.hexdigest(string).upcase
          end

          def acknowledge
            generate_signature == md5
          end

        end
      end
    end
  end
end