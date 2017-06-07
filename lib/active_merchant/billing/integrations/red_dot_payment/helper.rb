require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module RedDotPayment
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          REQUIRED_OPTIONS = [:credential2, :credential3]

          mapping :order, 'order_number'
          mapping :account, 'merchant_id'
          mapping :credential2, 'key'
          mapping :amount, 'amount'
          mapping :currency, 'currency_code'
          mapping :customer, :email => 'email'
          mapping :return_url, 'return_url'
          mapping :checksum, 'signature'

          def initialize(order, account, options = {})
            super
            REQUIRED_OPTIONS.each do |option|
              raise StandardError.new("No #{option} supplied in options") unless options[option].present?
            end

            @options = options
            add_field 'transaction_type', 'sale'
          end

          def form_fields
            @fields.merge(mappings[:checksum] => generate_checksum)
          end

          private

          def generate_checksum
            checksum_array = @fields.keys.sort().map do |field|
              "#{field}=#{@fields[field]}"
            end << "secret_key=#{@options[:credential3]}"

            checksum = checksum_array.join("&")

            Digest::MD5.hexdigest(checksum)
          end
        end
      end
    end
  end
end
