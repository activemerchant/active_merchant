require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Doku
        # # Example:
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
            status.present?
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

          def acknowledge(authcode = nil)
            true
          end

          private

          def parse(post)
            @raw = post.to_s
            for line in @raw.split('&')
              key, value = *line.scan( %r{^([A-Za-z0-9_.]+)\=(.*)$} ).flatten
              params[key] = CGI.unescape(value)
            end
          end

        end
      end
    end
  end
end
