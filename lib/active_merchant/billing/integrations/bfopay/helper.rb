module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Bfopay
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          mapping :account, 'MemberID'
          mapping :terminal_id, 'TerminalID'
          mapping :interface_version, 'InterfaceVersion'
          mapping :key_type, 'KeyType'
          mapping :pay_id, 'PayID'
          mapping :trade_date, 'TradeDate'
          mapping :order, 'TransID'
          mapping :amount, 'OrderMoney'
          mapping :description, 'ProductName'
          mapping :gateway_url, 'PageUrl'
          mapping :success_url, 'ReturnUrl'
          mapping :notice_type, 'NoticeType'
          mapping :signature, 'Signature'

        end
      end
    end
  end
end