require File.dirname(__FILE__) + '/maksuturva/helper.rb'
require File.dirname(__FILE__) + '/maksuturva/notification.rb'

# USAGE:
#
# First define Maksuturva seller id and authcode in an initializer:
#
#   MAKSUTURVA_SELLERID = "testikauppias"
#   MAKSUTURVA_AUTHCODE = "11223344556677889900"
#
# Then in view do something like this (use dynamic values for your app)
#
#   <% payment_service_for 2, MAKSUTURVA_SELLERID,
#           :amount => "200,00", :currency => 'EUR', :credential2 => MAKSUTURVA_AUTHCODE,
#           :service => :maksuturva do |service|
#       service.pmt_reference = "134662"
#       service.pmt_duedate = "24.06.2012"
#       service.customer :phone => "0405051909",
#           :email => "antti@example.com"
#       service.billing_address :city => "Helsinki",
#           :address1 => "Lorem street",
#           :state => "-",
#           :country => 'Finland',
#           :zip => "00530"
#       service.pmt_orderid = "2"
#       service.pmt_buyername = "Antti Akonniemi"
#       service.pmt_deliveryname = "Antti Akonniemi"
#       service.pmt_deliveryaddress = "Köydenpunojankatu 13"
#       service.pmt_deliverypostalcode = "00180"
#       service.pmt_deliverycity = "Helsinki"
#       service.pmt_deliverycountry = "FI"
#       service.pmt_rows = 1
#       service.pmt_row_name1 = "testi"
#       service.pmt_row_desc1 = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
#       service.pmt_row_articlenr1 = "1"
#       service.pmt_row_quantity1 = "1"
#       service.pmt_row_deliverydate1 = "26.6.2012"
#       service.pmt_row_price_gross1 = "200,00"
#       service.pmt_row_vat1= "23,00"
#       service.pmt_row_discountpercentage1 = "0,00"
#       service.pmt_row_type1 = "1"
#       service.pmt_charset = "UTF-8"
#       service.pmt_charsethttp = "UTF-8"
#
#       service.return_url "http://localhost:3000/process"
#       service.cancel_return_url "http://example.com"
#       service.pmt_errorreturn "http://example.com"
#
#       service.pmt_delayedpayreturn "http://example.com"
#       service.pmt_escrow "N"
#       service.pmt_escrowchangeallowed "N"
#       service.pmt_sellercosts "0,00"
#       service.pmt_keygeneration "001"
#        %>
#
# Then in the controller handle the return with something like this
#
#   def ipn
#     notify = ActiveMerchant::Billing::Integrations::Maksuturva::Notification.new(params)
#
#     if notify.acknowledge(MAKSUTURVA_AUTHCODE)
#       # Process order
#     else
#       # Show error
#     end
#   end
#
# For full list of available parameters etc check the integration documents
# here:
#
#   https://www.maksuturva.fi/services/vendor_services/integration_guidelines.html

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Maksuturva
        mattr_accessor :service_url
        self.service_url = 'https://www.maksuturva.fi/NewPaymentExtended.pmt'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
