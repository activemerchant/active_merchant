require File.dirname(__FILE__) +  '/smart_ps.rb'
require File.dirname(__FILE__) + '/braintree/braintree_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BraintreeOrangeGateway < SmartPs
      include BraintreeCommon

      self.display_name = 'Braintree (Orange Platform)'
 
      self.live_url = self.test_url = 'https://secure.braintreepaymentgateway.com/api/transact.php'

      def add_processor(post, options)
        post[:processor_id] = options[:processor] unless options[:processor].nil?
      end

      # Implements the suggestion as given here:
      # https://groups.google.com/forum/?fromgroups=#!topic/activemerchant/SZgiVs6bUmI
      #
      # This fixes Ubuntu 12.04 + OpenSSL 1.0.1c + Ruby 1.8/1.9 not being able to talk to the braintree gateway.
      # There is a ssl type negotiation issue:
      # curl https://secure.braintreepaymentgateway.com/api/transact.php # Fails
      # curl -I --sslv3 https://secure.braintreepaymentgateway.com/api/transact.php # Succeeds
      #
      class CrippledSslConnection < ActiveMerchant::Connection
        def configure_ssl(http)
          super(http)
          http.ssl_version = :SSLv3
        end
      end

      def new_connection(endpoint)
        CrippledSslConnection.new(endpoint)
      end
    end
  end
end

