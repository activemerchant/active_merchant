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
          mapping :partnerid, 'partner_id'
          mapping :sign, 'sing'
          mapping :orderid, 'order_id'
          mapping :amount, 'amount'
          mapping :currency, 'currency'
          mapping :details, 'details'
          mapping :nickname, 'nickname'
          mapping :lifetime, 'lifetime'
          mapping :successurl, 'successurl'
          mapping :declineurl, 'declineurl'
        end
      end
    end
  end
end
