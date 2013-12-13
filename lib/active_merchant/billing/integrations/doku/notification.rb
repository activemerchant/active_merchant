require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Doku
        # # Example:****
        # ## app/controllers/doku_controller.rb
        # class DokuController < ApplicationController
        #   include ActiveMerchant::Billing::Integrations
        #
        #   def notify
        #     parser = Doku::Notification.new(request.raw_post)
        #     order = Order.find_by_order_number(parser.item_id)
        #     if order && order.total == parser.gross
        #       # update order status according to parser.status (Success | Fail)
        #       render text: 'Continue'
        #     else
        #       render text: 'Stop'
        #     end
        #   end
        # end
        #

        class Notification < ActiveMerchant::Billing::Integrations::Notification

          self.production_ips = ['103.10.128.11', '103.10.128.14']

          def complete?
            if type == 'verify'
              params['STOREID'].present? && words.present?
            end
            status.present? if type == 'notify'
          end

          def item_id
            params['TRANSIDMERCHANT']
          end

          def gross
            params['AMOUNT']
          end

          def status
            case params['RESULT']
            when 'Success'
              'Completed'
            when 'Fail'
              'Failed'
            end
          end

          def currency
            'IDR'
          end

          def words
            params['WORDS']
          end

          def type
            if words
              'verify'
            elsif status
              'notify'
            end
          end

          def acknowledge(authcode = nil)
            case type
            when 'verify'
              words == Digest::SHA1.hexdigest("#{gross}#{@options[:credential2]}#{item_id}")
            when 'notify'
              true
            else
              false
            end
          end

        end
      end
    end
  end
end
