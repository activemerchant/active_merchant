module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Fatpay
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          # def initialize(order, account, options = {})
          #   super
          # end

          # mapping :api_key, 'api_key'
          # mapping :secret, 'secret'
          # mapping :expiration, 'expiration'
          # mapping :amount, 'amount'
          # mapping :currency, 'currency'
          # mapping :account, 'reference'
          # mapping :language, 'lang'
          # mapping :fail_url, 'failure_url'
          # mapping :description, 'description'

          mapping :data, 'data'
          mapping :signature, 'sign'

          # def generate_signature_string
          #   @fields.map{|k, v| "#{k}:#{v}" }.sort.push(@secret).join(';')
          # end

          # def generate_signature
          #   Digest::SHA1.hexdigest(generate_signature_string)
          # end

          # def form_fields
          #   @fields.merge('signature' => generate_signature )
          # end

        end
      end
    end
  end
end