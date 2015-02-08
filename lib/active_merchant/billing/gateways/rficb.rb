module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    module Rficb
      mattr_accessor :service_url
      self.service_url = 'https://partner.rficb.ru/a1lite/input/'

      mattr_accessor :signature_parameter_name
      self.signature_parameter_name = 'check'

      def self.notification(*args)
        Notification.new(*args)
      end

      def self.status(login, password)
        Status.new(login, password)
      end

      class Helper < OffsitePayments::Helper
        # public key
        mapping :account, 'key'

        mapping :amount, 'cost'

        mapping :order, 'order_id'

        mapping :customer, :email => 'email',
                           :phone => 'phone_number'

         # payment description
        mapping :credential2, 'name'

        mapping :credential3, 'comment'

        # on error
        # 1 - raise error
        # 0 - redirect
        mapping :credential4, 'verbose'
      end

      class Notification < OffsitePayments::Notification
        def initialize(*args)
          super
          guess_notification_type
        end

        # Simple notification request params:
        # tid
        # name
        # comment
        # partner_id
        # service_id
        # order_id
        # type
        # partner_income
        # system_income

        def complete?
          true
        end

        def transaction_id
          params['tid']
        end

        def title
          params['name']
        end

        def comment
          params['comment']
        end

        def partner_id
          params['partner_id']
        end

        def service_id
          params['service_id']
        end

        def item_id
          params['order_id']
        end

        def type
          params['type']
        end

        def partner_income
          params['partner_income']
        end

        def system_income
          params['system_income']
        end

        # Additional notification request params:
        # tid
        # name
        # comment
        # partner_id
        # service_id
        # order_id
        # type
        # cost
        # income_total
        # income
        # partner_income
        # system_income
        # command
        # phone_number
        # email
        # resultStr
        # date_created
        # version
        # check

        def income_total
          params['income_total']
        end

        def income
          params['income']
        end

        def partner_income
          params['partner_income']
        end

        def system_income
          params['system_income']
        end

        def command
          params['command']
        end

        def phone_number
          params['phone_number']
        end

        def payer_email
          params['email']
        end

        def result_string
          params['resultStr']
        end

        def received_at
          params['date_created']
        end

        def version
          params['version']
        end

        def security_key
          params[Rficb.signature_parameter_name].to_s.downcase
        end

        # the money amount we received in X.2 decimal.
        alias_method :gross, :system_income

        def currency
          'RUB'
        end

        # Was this a test transaction?
        def test?
          params['test'] == '1'
        end

        def simple_notification?
          @notification_type == :simple
        end

        def additional_notification?
          @notification_type == :additional
        end

        def acknowledge(authcode = nil)
          security_key == signature
        end

        private

        def signature
          data = "#{params['tid']}\
#{params['name']}\
#{params['comment']}\
#{params['partner_id']}\
#{params['service_id']}\
#{params['order_id']}\
#{params['type']}\
#{params['partner_income']}\
#{params['system_income']}\
#{params['test']}\
#{@options[:secret]}"
          Digest::MD5.hexdigest(data)
        end

        def guess_notification_type
          @notification_type = params['version'] ? :additional : :simple
        end
      end

      class Status
        include ActiveUtils::PostsData

        STATUS_TEST_URL = 'https://partner.rficb.ru/a1lite/input/'

        attr_accessor :login, :password

        def initialize(login, password)
          @login, @password = login, password
        end

        # agregator provides two methods:
        # by tid - transaction id
        # by order_id & service_id
        def update(options = {})
          data = PostData.new
          data[:user] = @login
          data[:pass] = @password
          if options[:tid]
            data[:tid] = options[:tid]
          else
            data[:ord_id] = options[:ord_id]
            data[:service_id] = options[:service_id]
          end

          ssl_post(STATUS_TEST_URL, data.to_post_data)
        end
      end
    end
  end
end
