require 'cgi'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Alipay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          CREATE_DIRECT_PAY_BY_USER = 'create_direct_pay_by_user'
          CREATE_PARTNER_TRADE_BY_BUYER = 'create_partner_trade_by_buyer'
          TRADE_CREATE_BY_BUYER = 'trade_create_by_buyer'
          CREATE_FOREIGN_TRADE = 'create_forex_trade'

          ###################################################
          # common
          ###################################################
          mapping :account, 'partner'
          mapping :order, 'out_trade_no'
          mapping :seller, :email => 'seller_email',
                           :id => 'seller_id'
          mapping :buyer, :email => 'buyer_email',
                          :id => 'buyer_id'
          mapping :notify_url, 'notify_url'
          mapping :return_url, 'return_url'
          mapping :show_url, 'show_url'
          mapping :body, 'body'
          mapping :subject, 'subject'
          mapping :charset, '_input_charset'
          mapping :service, 'service'
          mapping :payment_type, 'payment_type'
          mapping :extra_common_param, 'extra_common_param'
          mapping :currency, 'currency'

          #################################################
          # create direct pay by user
          #################################################
          mapping :total_fee, 'total_fee'
          mapping :paymethod, 'paymethod'
          mapping :defaultbank, 'defaultbank'
          mapping :royalty, :type => 'royalty_type',
                            :parameters => 'royalty_parameters'
          mapping :it_b_pay, 'it_b_pay'

          #################################################
          # create partner trade by buyer and trade create by user
          #################################################
          mapping :price, 'price'
          mapping :quantity, 'quantity'
          mapping :discount, 'discount'
          ['', '_1', '_2', '_3'].each do |postfix|
            self.class_eval <<-EOF
            mapping :logistics#{postfix}, :type => 'logistics_type#{postfix}',
                                          :fee => 'logistics_fee#{postfix}',
                                          :payment => 'logistics_payment#{postfix}'
            EOF
          end
          mapping :receive, :name => 'receive_name',
                            :address => 'receive_address',
                            :zip => 'receive_zip',
                            :phone => 'receive_phone',
                            :mobile => 'receive_mobile'
          mapping :t_b_pay, 't_b_pay'
          mapping :t_s_send_1, 't_s_send_1'
          mapping :t_s_send_2, 't_s_send_2'

          #################################################
          # create partner trade by buyer
          #################################################
          mapping :agent, 'agent'
          mapping :buyer_msg, 'buyer_msg'

          def initialize(order, account, options = {})
            super
          end

          def sign
            add_field('sign',
                      Digest::MD5.hexdigest((@fields.sort.collect{|s|s[0]+"="+CGI.unescape(s[1])}).join("&")+KEY)
                     )
            add_field('sign_type', 'MD5')
            nil
          end

        end
      end
    end
  end
end
