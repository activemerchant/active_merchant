module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module EasyPay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Common

          def initialize(order, account, options = {})
            super
            @secret = options[:credential2]
          end

          def form_fields
            @fields.merge(ActiveMerchant::Billing::Integrations::EasyPay.signature_parameter_name => generate_signature(:request))
          end

          def params
            @fields
          end

          mapping :account, 'EP_MerNo'
          mapping :amount, 'EP_Sum'
          mapping :order, 'EP_OrderNo'
          mapping :comment, 'EP_Comment'
          mapping :order_info, 'EP_OrderInfo'
          mapping :expires, 'EP_Expires'
          mapping :success_url, 'EP_Success_URL'
          mapping :cancel_url, 'EP_Cancel_URL'
          mapping :debug, 'EP_Debug'
          mapping :url_type, 'EP_URL_Type'
          mapping :encoding, 'EP_Encoding'
        end
      end
    end
  end
end
