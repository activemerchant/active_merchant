module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Doku
        # # Example:
        # ## app/controllers/doku_controller.rb
        # class DokuController < ApplicationController
        #   include ActiveMerchant::Billing::Integrations
        #
        #   def verify
        #     parser = Doku::Verification.new(request.raw_post)
        #     order = Order.find_by_order_number(parser.transaction_id)
        #
        #     if account == parser.storeid && order && order.total == parser.gross
        #       render text: 'Continue'
        #     else
        #       render text: 'Stop'
        #     end
        #   end
        # end
        #

        class Verification
          attr_reader :storeid, :transaction_id, :gross, :words

          def initialize(params={})
            @storeid         = params['STOREID']
            @transaction_id  = params['TRANSIDMERCHANT']
            @gross           = params['AMOUNT']
            @words           = params['WORDS']
          end

        end

      end
    end
  end
end