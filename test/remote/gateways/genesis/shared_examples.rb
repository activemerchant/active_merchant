%w(api helpers).each do |file|
  require "active_merchant/billing/gateways/genesis/#{file}"
end

require_relative 'shared_examples/transactions'
require_relative 'test_helper'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples

        include Transactions
        include RemoteTestHelper

        Api::Errors::RESPONSE_CODES.each do |key, _|
          name = "response_code_#{key}"
          define_method(name) { Api::Errors::RESPONSE_CODES[key] }
        end

        Api::Errors::ISSUER_RESPONSE_CODES.each do |key, _|
          name = "issuer_code_#{key}"
          define_method(name) { Api::Errors::ISSUER_RESPONSE_CODES[key] }
        end

        def test_failed_store_card
          add_credit_cards(:visa)

          response = @gateway.store(@approved_visa, @order_details)

          assert_response_instance(response)
          assert_failure response
        end

        def test_failed_unstore_card
          response = @gateway.unstore(0, 0, @order_details)

          assert_response_instance(response)
          assert_failure response
        end

        def test_invalid_login
          set_invalid_gateway_credentials
          add_credit_cards(:visa)

          response = @gateway.purchase(@amount, @approved_visa, @order_details)

          expect_failed_response(response,
                                 status: TransactionStates::ERROR,
                                 code:   response_code_merchant_login_failed)
        end

        private

        def assert_response_instance(response)
          assert_instance_of Response, response
        end

        def prepare_shared_test_data
          save_order_details
        end

        def save_order_details
          @amount        = generate_order_amount
          @order_details = build_base_order_details

          save_all_order_address_details
        end

        def order_address_types
          %w(billing shipping)
        end

        def save_all_order_address_details
          order_address_types.each do |address_type|
            save_order_address_details(address_type)
          end
        end

        def save_order_address_details(address_type)
          return unless order_address_types.include?(address_type)

          @order_details["#{address_type}_address".to_sym] = build_order_address_details
        end

        def add_successful_description(description)
          add_description('Successful', description)
        end

        def add_failed_description(description)
          add_description('Failed', description)
        end

        def add_description(expected_result, description)
          @order_details[:description] = "Active Merchant - Test #{expected_result} #{description}"
        end

        def set_invalid_gateway_credentials
          %w(username password token).each do |param|
            @gateway.options[param.to_sym] = "fake_#{param}"
          end
        end

        def assert_includes(expected_items, actual, failure_message = nil)
          return unless expected_items.is_a? Array

          assert_equal(true,
                       expected_items.include?(actual),
                       failure_message)
        end

        def response_codes_invalid_card
          [response_code_invalid_card_error, response_code_blacklist_error]
        end
      end
    end
  end
end
