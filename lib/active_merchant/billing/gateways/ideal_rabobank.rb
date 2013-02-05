require File.dirname(__FILE__) + '/ideal/ideal_base'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # First, make sure you have everything setup correctly and all of your dependencies in place with:
    #
    #    require 'rubygems'
    #    require 'active_merchant'
    #
    # ActiveMerchant expects the amounts to be given as an Integer in cents. In this case, 10 EUR becomes 1000.
    #
    # Create certificates for authentication:
    #
    # The PEM file expected should contain both the certificate and the generated PEM file.
    # Some sample shell commands to generate the certificates:
    #
    #    openssl genrsa -aes128 -out priv.pem -passout pass:[YOUR PASSWORD] 1024
    #    openssl req -x509 -new -key priv.pem -passin pass:[YOUR PASSWORD] -days 3000 -out cert.cer
    #    cat cert.cer priv.pem > ideal.pem
    #
    # Following the steps above, upload cert.cer to the ideal web interface and pass the path of ideal.pem to the :pem option.
    #
    # Configure the gateway using your iDEAL bank account info and security settings:
    #
    # Create gateway:
    #    gateway = ActiveMerchant::Billing::IdealRabobankGateway.new(
    #      :login    => '123456789', # 9 digit merchant number
    #      :pem      => File.read(Rails.root + 'config/ideal.pem'),
    #      :password => 'password' # password for the PEM key
    #    )
    #
    # Get list of issuers to fill selection list on your payment form:
    #    response = gateway.issuers
    #    list = response.issuer_list
    #
    # Request transaction:
    #
    #    options = {
    #       :issuer_id         => '0001',
    #       :expiration_period => 'PT10M',
    #       :return_url        => 'http://www.return.url',
    #       :order_id          => '1234567890123456',
    #       :currency          => 'EUR',
    #       :description       => 'Een omschrijving',
    #       :entrance_code     => '1234'
    #    }
    #
    #    response = gateway.setup_purchase(amount, options)
    #    transaction_id = response.transaction['transactionID']
    #    redirect_url = response.service_url
    #
    # Mandatory status request will confirm transaction:
    #    response = gateway.capture(transaction_id)
    #
    # Implementation contains some simplifications
    # - does not support multiple subID per merchant
    # - language is fixed to 'nl'
    class IdealRabobankGateway < IdealBaseGateway
      class_attribute :test_url, :live_url

      self.test_url = 'https://idealtest.rabobank.nl/ideal/iDeal'
      self.live_url = 'https://ideal.rabobank.nl/ideal/iDeal'
      self.server_pem = File.read(File.dirname(__FILE__) + '/ideal/ideal_rabobank.pem')
    end
  end
end
