module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paydollar
        
        # Example:
        # * You may use this on your view/html page
        #
        # ActiveMerchant::Billing::Base.integration_mode = :test
        # payment_service_for('order_id', 'your_merchant_id_from_paydollar', :amount => 100.00, :service => :paydollar, :credential2 => 'your_secure_hash_secret_from_paydollar') do |service|
        #   service.payment_method "ALL"
        #   service.payment_type "N"
        #   service.currency "HKD"
        #   service.language "E"
        #   service.success_url "http://www.yourdomain.com/success.html"
        #   service.fail_url "http://www.yourdomain.com/fail.html"
        #   service.cancel_url "http://www.yourdomain.com/cancel.html"
        #   service.description "For order id number X"
        #   service.secure_hash_enabled "yes" 
        # end
        
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include RequiresParameters
          
          # Currencies supported - Depends on Merchant Account Settings at PayDollar                 
          SUPPORTED_CURRENCIES_MAP = {
            'PHP' => '608', 
            'USD' => '840', 
            'HKD' => '344', 
            'SGD' => '702', 
            'CNY' => '156', 
            'JPY' => '392',
            'TWD' => '901',
            'AUD' => '036',
            'EUR' => '978',
            'GBP' => '826',
            'CAD' => '124',
            'MOP' => '446',
            'THB' => '764',
            'MYR' => '458',
            'IDR' => '360',
            'KRW' => '410',
            'SAR' => '682',
            'NZD' => '554',
            'AED' => '784',
            'BND' => '096',
          }
          
          # Languages supported
          # E - English
          # C - Traditional Chinese
          # X - Simplified Chinese
          # K - Korean
          # J - Japanese
          # T - Thai
          # F - French
          # G - German
          # R - Russian
          # S - Spanish
          SUPPORTED_LANGS = %w[E C X K J T F G R S]
          
          # Payment methods supported - Depends on Merchant Account Settings at PayDollar
          # ALL - All the available payment method
          # CC - Credit Card Payment
          # VISA - Visa Payment
          # Master - MasterCard Payment
          # JCB - JCB Payment
          # AMEX - AMEX Payment
          # Diners - Dirers Club Payment
          # PAYPAL - PayPal
          # BancNet - BancNet Debit Payment
          # GCash - GCash Payment
          # SMARTMONEY - Smartmoney Payment
          # PPS - PPS Payment
          # CHINAPAY - China UnionPay
          # ALIPAY - ALIPAY Payment
          # TENPAY - TENPAY Payment
          # 99BILL - 99BILL Payment
          # MEPS - MEPS Payment
          # SCB - SCB (SCB Easy) Payment
          # BPM - Bill Payment
          # KTB - Krung Thai Bank (KTB Online) Payment
          # UOB - United Oversea Bank Payment
          # KRUNGSRIONLINE - Bank of Ayudhya (KRUNGSRIONLINE)
          # TMB - TMB Bank Payment
          # IBANKING - Bankok Bank iBanking Payment
          # UPOP - UPOP Payment
          # PAYCASH - PayCash All Partners
          # OTCPH-BDO - PayCash BDO
          # OTCPH-BAYAD - PayCash Bayad Center
          # OTCPH-CEBUANA - PayCash Cebuana Lhuillier
          # OTCPH-RCBC - PayCash RCBC
          # OTCPH-ECPAY - PayCash ECPAY
          SUPPORTED_PAYMENT_METHODS = %w[ALL CC VISA Master JCB AMEX Diners PAYPAL BancNet GCash SMARTMONEY PPS CHINAPAY ALIPAY TENPAY 99BILL MEPS SCB BPM KTB UOB KRUNGSRIONLINE TMB IBANKING UPOP PAYCASH OTCPH-BDO OTCPH-BAYAD OTCPH-CEBUANA OTCPH-RCBC OTCPH-ECPAY]
          
          # Payment Types supported - Depends on Merchant Account Settings at PayDollar
          # N - Sale
          # H - Authorize
          SUPPORTED_PAYMENT_TYPES = %w[N H]
          
          attr_reader :secure_hash_secret
          
          def initialize(order, account, options = {})   
            @secure_hash_secret = options[:credential2]         
            super
          end
          
          def currency(curr_symbol)
            raise ArgumentError, "unsupported currency" unless SUPPORTED_CURRENCIES_MAP.key?(curr_symbol)
            add_field mappings[:currency], SUPPORTED_CURRENCIES_MAP[curr_symbol.to_s]
          end
          
          def language(lang)
            raise ArgumentError, "unsupported language" unless SUPPORTED_LANGS.include?(lang)
            add_field mappings[:language], lang
          end
          
          def payment_method(pay_method)
            raise ArgumentError, "unsupported payment method" unless SUPPORTED_PAYMENT_METHODS.include?(pay_method)
            add_field mappings[:payment_method], pay_method
          end
          
          def payment_type(pay_type)
            raise ArgumentError, "unsupported payment type" unless SUPPORTED_PAYMENT_TYPES.include?(pay_type)
            add_field mappings[:payment_type], pay_type
          end
          
          def success_url(url)            
            add_field mappings[:success_url], url
          end
          
          def fail_url(url)            
            add_field mappings[:fail_url], url
          end
                    
          def cancel_url(url)            
            add_field mappings[:cancel_url], url
          end
          
          def secure_hash_enabled(yes_no)
            if yes_no == 'yes'
              generated_key = Digest::SHA1.hexdigest(
                fields[mappings[:account]] + "|" +
                fields[mappings[:order]] + "|" +
                fields[mappings[:currency]] + "|" +
                fields[mappings[:amount]] + "|" +
                fields[mappings[:payment_type]] + "|" +
                secure_hash_secret
              )
              add_field mappings[:secure_hash], generated_key
            end
          end
          
          # Replace with the real mapping
          mapping :order, 'orderRef'
          mapping :amount, 'amount'
          mapping :account, 'merchantId'
          mapping :payment_method, 'payMethod'
          mapping :payment_type, 'payType'
          mapping :currency, 'currCode'
          mapping :language, 'lang'
          mapping :success_url, 'successUrl'
          mapping :fail_url, 'failUrl'
          mapping :cancel_url, 'cancelUrl'
          mapping :secure_hash, 'secureHash'
          mapping :description, 'remark'          

        end
      end
    end
  end
end
