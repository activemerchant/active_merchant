%w(api helpers).each do |file|
  require "active_merchant/billing/gateways/genesis/#{file}"
end

require_relative 'shared_examples/transactions'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples

        include Transactions

        RESPONSE_SUCCESS_MSG            = 'TESTMODE: No real money will be transferred!'.freeze
        RESPONSE_SUCCESS_TECH_MSG       = 'TESTMODE: No real money will be transferred!'.freeze
        RESPONSE_SUCCESS_UNQ_ID         = '4f01752204eef8eba95d2b657f8ab853'.freeze
        RESPONSE_SUCCESS_TXN_ID         = '02b7a37b92eb7838a105c3d3a503e096'.freeze
        RESPONSE_SUCCESS_REF_TXN_UNQ_ID = '2d53f63ba8543e10be851b0718b6ab2a'.freeze
        RESPONSE_SUCCESS_REF_TXN_ID     = 'ab2ad283bd49986cb9f0ffab9816aefd'.freeze

        RESPONSE_FAILED_MSG_CARD_INVALID      = 'Credit card number is invalid.'.freeze
        RESPONSE_FAILED_TECH_MSG_CARD_INVALID = 'card_number is invalid or missing'.freeze
        RESPONSE_FAILED_MSG_INVALID_REF_TXN   = 'Reference Transaction could not be found!'.freeze
        RESPONSE_FAILED_UNQ_ID                = 'ab8a9131307d6706ae6fc51bf80e7bdf'.freeze
        RESPONSE_FAILED_TXN_ID                = 'c275ff95680dd38f2ae297985a39dc21'.freeze

        RESPONSE_MSG_CONTACT_SUPPORT = 'Please, try again or contact support!'.freeze
        RESPONSE_MODE                = 'test'.freeze
        RESPONSE_DESCRIPTOR          = 'test'.freeze

        Api::Errors::RESPONSE_CODES.each do |key, _|
          name = "response_code_#{key}"
          define_method(name) { Api::Errors::RESPONSE_CODES[key] }
        end

        Api::Errors::ISSUER_RESPONSE_CODES.each do |key, _|
          name = "issuer_code_#{key}"
          define_method(name) { Api::Errors::ISSUER_RESPONSE_CODES[key] }
        end

        def test_scrub
          assert_equal true, @gateway.supports_scrubbing?
        end

        private

        def prepare_shared_test_data(credit_card)
          @credit_card     = credit_card
          @amount          = 100

          @options = {
            order_id:        1,
            billing_address: address,
            description:     'Store Purchase'
          }
        end

        def expect_successful_response(response, expected_params)
          assert_success response

          response_params = response.params

          assert_nil response_params['code']
          assert_nil response.error_code

          assert_equal response_params['transaction_type'], expected_params[:transaction_type]
          assert_equal response_params['response_code'], issuer_code_approved

          assert response.message

          assert_equal response.authorization, expected_params[:unique_id]

          expect_response_params(response, expected_params)

          assert response.test?
        end

        def expect_failed_response(response, expected_params)
          assert_failure response

          expect_response_params(response, expected_params)

          assert response.message
          assert response.error_code

          assert_mapped_response_code(response, expected_params)
          assert_nil response.authorization
        end

        def expect_response_params(response, expected_params)
          return unless expected_params

          expected_params.each do |key, value|
            assert_equal(value, response.params[key.to_s]) if value.present?
          end
        end

        def assert_mapped_response_code(response, items)
          response_params = response.params

          return unless items.include?('code') && response_params.key?('code')

          mapped_response_error_code = Helpers::Response.map_error_code(response_params['code'])

          assert_equal mapped_response_error_code, response.error_code
        end

        def build_initial_purchase_trx
          successful_purchase_response = successful_init_trx_response(TransactionTypes::SALE)

          @gateway.expects(:ssl_post).returns(successful_purchase_response)

          @gateway.purchase(@amount, @credit_card, @options)
        end

        def build_initial_auth_trx
          successful_auth_response = successful_init_trx_response(TransactionTypes::AUTHORIZE)

          @gateway.expects(:ssl_post).returns(successful_auth_response)

          @gateway.authorize(@amount, @credit_card, @options)
        end
      end
    end
  end
end
