module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module YandexMoney
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          
          mapping :request_datetime, 'requestDatetime'
          mapping :action, 'action'
          mapping :md5, 'md5'
          mapping :shop_id, 'shopId'
          mapping :shop_article_id, 'shopArticleId'
          mapping :invoice_id, 'invoiceId'
          mapping :order_number, 'orderNumber'
          mapping :customer_number, 'customerNumber'
          mapping :order_created_datetime, 'orderCreatedDatetime'
          mapping :order_sum_amount, 'orderSumAmount'
          mapping :order_sum_currency_paycash, 'orderSumCurrencyPaycash'
          mapping :order_sum_bank_paycash, 'orderSumBankPaycash'
          mapping :shop_sum_amount, 'shopSumAmount'
          mapping :shop_sum_currency_paycash, 'shopSumCurrencyPaycash'
          mapping :shop_sum_bank_paycash, 'shopSumBankPaycash'
          mapping :payment_payer_code, 'paymentPayerCode'
          mapping :payment_type, 'paymentType'
          mapping :amount, 'sum'
          mapping :scid, 'scid'
          mapping :user_id, 'customerNumber'
          mapping :payment_id, 'orderNumber'
          mapping :payment_type, 'paymentType'
          mapping :fail_url, 'shopFailURL'
          mapping :succes_url, 'shopSuccessURL'

        end
      end
    end
  end
end