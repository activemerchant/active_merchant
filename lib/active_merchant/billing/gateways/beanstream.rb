require 'active_merchant/billing/gateways/beanstream/beanstream_default'
require 'active_merchant/billing/gateways/beanstream/beanstream_ipp'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This class implements the Canadian {Beanstream}[http://www.beanstream.com] payment gateway.
    # It is also named TD Canada Trust Online Mart payment gateway.
    # To learn more about the specification of Beanstream gateway, please read the OM_Direct_Interface_API.pdf,
    # which you can get from your Beanstream account or get from me by email.
    #
    # == Supported transaction types by Beanstream:
    # * +P+ - Purchase
    # * +PA+ - Pre Authorization
    # * +PAC+ - Pre Authorization Completion
    #
    # == Secure Payment Profiles:
    # BeanStream supports payment profiles (vaults). This allows you to store cc information with BeanStream and process subsequent transactions with a customer id.
    # Secure Payment Profiles must be enabled on your account (must be done over the phone).
    # Your API Access Passcode must be set in Administration => account settings => order settings.
    # To learn more about storing credit cards with the Beanstream gateway, documentation can be found at http://developer.beanstream.com/documentation/classic-apis
    #
    # To store a credit card using Beanstream's Legato Javascript Library (http://developer.beanstream.com/documentation/legato) you must pass the singleUseToken in
    # the store method's option parameter. Example: @gateway.store("gt6-0c78c25b-3637-4ba0-90e2-26105287f198")
    #
    # == Notes
    # * Adding of order products information is not implemented.
    # * Ensure that country and province data is provided as a code such as "CA", "US", "QC".
    # * login is the Beanstream merchant ID, username and password should be enabled in your Beanstream account and passed in using the <tt>:user</tt> and <tt>:password</tt> options.
    # * Test your app with your true merchant id and test credit card information provided in the api pdf document.
    # * Beanstream does not allow Payment Profiles to be deleted with their API. The accounts are 'closed', but have to be deleted manually.
    #
    #  Example authorization (Beanstream PA transaction type):
    #
    #   twenty = 2000
    #   gateway = BeanstreamGateway.new(
    #     :login => '100200000',
    #     :user => 'xiaobozz',
    #     :password => 'password'
    #   )
    #
    #   credit_card = CreditCard.new(
    #     :number => '4030000010001234',
    #     :month => 8,
    #     :year => 2011,
    #     :first_name => 'xiaobo',
    #     :last_name => 'zzz',
    #     :verification_value => 137
    #   )
    #   response = gateway.authorize(twenty, credit_card,
    #     :order_id => '1234',
    #     :billing_address => {
    #       :name => 'xiaobo zzz',
    #       :phone => '555-555-5555',
    #       :address1 => '1234 Levesque St.',
    #       :address2 => 'Apt B',
    #       :city => 'Montreal',
    #       :state => 'QC',
    #       :country => 'CA',
    #       :zip => 'H2C1X8'
    #     },
    #     :email => 'xiaobozzz@example.com',
    #     :subtotal => 800,
    #     :shipping => 100,
    #     :tax1 => 100,
    #     :tax2 => 100,
    #     :custom => 'reference one'
    #   )

    class BeanstreamGateway < Gateway
      def self.new(options = {})
        klass = 
          case options[:region]
          when nil, :america
            BeanstreamDefautGateway
          when :pacific
            BeanstreamIppGateway
          else
            raise ArgumentError, "invalid region #{options[:region]}"
          end

        klass.new(options)
      end
    end
  end
end
