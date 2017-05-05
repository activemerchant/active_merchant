module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Quickpay
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, account, options = {})
            md5secret options.delete(:credential2)
            super
            add_field('protocol', '7')
            add_field('msgtype', 'authorize')
            add_field('language', 'da')
            add_field('autocapture', 0)
            add_field('testmode', test? ? 1 : 0)
            add_field('ordernumber', format_order_number(order))
          end

          def md5secret(value)
            @md5secret = value
          end

          def form_fields
            @fields.merge('md5check' => generate_md5check)
          end

          def generate_md5string
            MD5_CHECK_FIELDS.map {|key| @fields[key.to_s]} * "" + @md5secret
          end

          def generate_md5check
            Digest::MD5.hexdigest(generate_md5string)
          end

          # Limited to 20 digits max
          def format_order_number(number)
            number.to_s.gsub(/[^\w]/, '').rjust(4, "0")[0...20]
          end

          MD5_CHECK_FIELDS = [
            :protocol,
            :msgtype,
            :merchant,
            :language,
            :ordernumber,
            :amount,
            :currency,
            :continueurl,
            :cancelurl,
            :callbackurl,
            :autocapture,
            :autofee,
            :cardtypelock,
            :description,
            :group,
            :testmode,
            :splitpayment,
            :forcemobile,
            :deadline,
            :cardhash
          ]

          mapping :protocol, 'protocol'
          mapping :msgtype, 'msgtype'
          mapping :account, 'merchant'
          mapping :language, 'language'
          mapping :amount, 'amount'
          mapping :currency, 'currency'

          mapping :return_url, 'continueurl'
          mapping :cancel_return_url, 'cancelurl'
          mapping :notify_url, 'callbackurl'

          mapping :autocapture, 'autocapture'
          mapping :autofee, 'autofee'
          mapping :cardtypelock, 'cardtypelock'

          mapping :ipaddress, 'ipaddress'

          mapping :description, 'description'
          mapping :group, 'group'
          mapping :testmode, 'testmode'

          mapping :splitpayment, 'splitpayment'
          mapping :forcemobile, 'forcemobile'
          mapping :deadline, 'deadline'
          mapping :cardhash, 'cardhash'

          mapping :customer, ''
          mapping :billing_address, {}
          mapping :tax, ''
          mapping :shipping, ''
        end
      end
    end
  end
end
