module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Molpay

        # Example.
        #
        #  (Optional Parameter) = channel //will generate URL to go directly to specific channel, e.g maybank2u, cimb 
        #  Please refer MOLPay API spec for the channel routing
        #
        #  payment_service_for('ORDER_ID', 'MOLPAY_MERCHANT_ID', :service => :molpay,  :amount => 1.01, :currency => 'MYR', :credential2 => 'MOLPAY_VERIFICATION_KEY', :channel => 'maybank2u.php') do |service|
        #
        #    service.customer :name              => 'Your Name',
        #                     :email             => 'name@molpay.com',
        #                     :phone             => '60355218438'
        #
        #    service.description "Payment for Item 001"
        #
        #    service.country "MY"
        #
        #    service.language "en"
        #
        #    service.return_url 'http://yourstore.com/return'
        #
        # end
        #
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          
          #Currencies supported
          #MYR (Malaysian Ringgit - Malaysia Payment Gateway (Credit Card & local debit payment), Union Pay, Alipay)
          #USD (US Dollar)
          #SGD (Singapore Dollar)
          #PHP (Philippines Peso)
          #VND (Vietnamese Dong)
          #IDR (Indonesian Rupiah)
          #AUD (Australian Dollar)
          SUPPORTED_CURRENCIES = [ 'MYR', 'USD', 'SGD', 'PHP', 'VND', 'IDR', 'AUD']

          #Languages supported
          #en English (default)
          #cn Simplified Chinese
          SUPPORTED_LANGUAGES = ['en', 'cn']

          SERVICE_URL = 'https://www.onlinepayment.com.my/MOLPay/pay/'.freeze

          mapping :account, 'merchantid'
          mapping :amount, 'amount'
          mapping :order, 'orderid'
          mapping :customer, :name  => 'bill_name',
                             :email => 'bill_email',
                             :phone => 'bill_mobile'

          mapping :description, 'bill_desc'
          mapping :language, 'langcode'
          mapping :country, 'country'
          mapping :currency, 'cur'
          mapping :return_url, 'returnurl'
          mapping :signature, 'vcode'


          attr_reader :amount_in_cents, :verify_key, :channel

          def credential_based_url
            service_url = SERVICE_URL + @fields[mappings[:account]] + "/"
            service_url = service_url + @channel unless @channel.blank?
            service_url
          end

          def initialize(order, account, options = {})
            @verify_key = options[:credential2] if options[:credential2]
            @amount_in_cents = options[:amount]
            @channel = options[:channel] if options[:channel]
            options.delete(:channel)
            super
            raise 'missing parameter' unless account and options[:currency]
          end

          def form_fields
            add_field mappings[:signature], signature
            @fields
          end

          def amount=(money)
            #Molpay minimum amount is 1.01
            if money.is_a?(String) or money.to_f < 1.01
              raise ArgumentError, "money amount must be either a Money object or a positive integer."
            end
            add_field mappings[:amount], sprintf("%.2f", money.to_f)
          end

          def currency(cur)
            raise ArgumentError, "unsupported currency" unless SUPPORTED_CURRENCIES.include?(cur)
            add_field mappings[:currency], cur
          end

          def language(lang)
            raise ArgumentError, "unsupported language" unless SUPPORTED_LANGUAGES.include?(lang)
            add_field mappings[:language], lang
          end


          private

          def signature
            Digest::MD5.hexdigest("#{@fields[mappings[:amount]]}#{@fields[mappings[:account]]}#{@fields[mappings[:order]]}#{@verify_key}")
          end
        end
      end
    end
  end
end