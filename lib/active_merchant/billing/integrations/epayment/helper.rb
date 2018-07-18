# frozen_string_literal: true

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Epayment
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
          end

          mapping :token, 'token'
          mapping :account, 'partnerid'
          mapping :sign, 'sign'
          mapping :payment_id, 'orderid'
          mapping :amount, 'amount'
          mapping :currency, 'currency'
          mapping :description, 'details'
          mapping :nickname, 'nickname,'
          mapping :lifetime, 'lifetime'
          mapping :success_url, 'successurl'
          mapping :decline_url, 'declineurl'
        end
      end
    end
  end
end
