module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module TransactionTypes

        SALE         = 'sale'.freeze
        SALE_3D      = 'sale3d'.freeze
        AUTHORIZE    = 'authorize'.freeze
        AUTHORIZE_3D = 'authorize3d'.freeze
        CAPTURE      = 'capture'.freeze
        REFUND       = 'refund'.freeze
        VOID         = 'void'.freeze
      end
    end
  end
end
