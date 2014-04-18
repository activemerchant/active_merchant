module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Cashnet < Gateway
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url        = 'http://www.higherone.com/'
      self.display_name        = 'Cashnet'
      self.money_format        = :dollars

      # Creates a new CashnetGateway
      #
      # ==== Options
      #
      # * <tt>:gateway_merchant_name</tt> -- The Gateway Merchant Name (REQUIRED)
      # * <tt>:station</tt> -- Station (REQUIRED)
      # * <tt>:operator</tt> -- Operator (REQUIRED)
      # * <tt>:password</tt> -- Password (REQUIRED)
      # * <tt>:credit_card_payment_code </tt> -- Credit Card Payment Code  (REQUIRED)
      # * <tt>:customer_code</tt> -- Customer Code (REQUIRED)
      # * <tt>:item_code</tt> -- Item code (REQUIRED)
      # * <tt>:site_name</tt> -- Site name (REQUIRED)
      # * <tt>:test</tt> -- set to true for TEST mode or false for LIVE mode
      def initialize(options = {})
        requires!(options, :gateway_merchant_name, :station, :operator,
          :password, :credit_card_payment_code, :customer_code, :item_code, :site_name)
        super
      end


    end
  end
end