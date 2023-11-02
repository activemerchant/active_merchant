require 'test_helper'

class BraintreeTokenNonceTest < Test::Unit::TestCase
  def setup
    @gateway = BraintreeBlueGateway.new(
      merchant_id: 'test',
      public_key: 'test',
      private_key: 'test',
      test: true
    )

    @braintree_backend = @gateway.instance_eval { @braintree_gateway }

    @options = {
      billing_address: {
        name: 'Adrain',
        address1: '96706 Onie Plains',
        address2: '01897 Alysa Lock',
        country: 'XXX',
        city: 'Miami',
        state: 'FL',
        zip: '32191',
        phone_number: '693-630-6935'
      },
      ach_mandate: 'ach_mandate'
    }
    @generator = TokenNonce.new(@braintree_backend, @options)
    @no_address_generator = TokenNonce.new(@braintree_backend, { ach_mandate: 'ach_mandate' })
  end

  def test_build_nonce_request_for_credit_card
    credit_card = credit_card('4111111111111111')
    response = @generator.send(:build_nonce_request, credit_card)
    parse_response = JSON.parse response
    assert_client_sdk_metadata(parse_response)
    assert_equal normalize_graph(parse_response['query']), normalize_graph(credit_card_query)
    assert_includes parse_response['variables']['input'], 'creditCard'

    credit_card_input = parse_response['variables']['input']['creditCard']

    assert_equal credit_card_input['number'], credit_card.number
    assert_equal credit_card_input['expirationYear'], credit_card.year.to_s
    assert_equal credit_card_input['expirationMonth'], credit_card.month.to_s.rjust(2, '0')
    assert_equal credit_card_input['cvv'], credit_card.verification_value
    assert_equal credit_card_input['cardholderName'], credit_card.name
    assert_billing_address_mapping(credit_card_input, credit_card)
  end

  def test_build_nonce_request_for_bank_account
    bank_account = check({ account_number: '4012000033330125', routing_number: '011000015' })
    response = @generator.send(:build_nonce_request, bank_account)
    parse_response = JSON.parse response
    assert_client_sdk_metadata(parse_response)
    assert_equal normalize_graph(parse_response['query']), normalize_graph(bank_account_query)
    assert_includes parse_response['variables']['input'], 'usBankAccount'

    bank_account_input = parse_response['variables']['input']['usBankAccount']

    assert_equal bank_account_input['routingNumber'], bank_account.routing_number
    assert_equal bank_account_input['accountNumber'], bank_account.account_number
    assert_equal bank_account_input['accountType'], bank_account.account_type.upcase
    assert_equal bank_account_input['achMandate'], @options[:ach_mandate]

    assert_billing_address_mapping(bank_account_input, bank_account)

    assert_equal bank_account_input['individualOwner']['firstName'], bank_account.first_name
    assert_equal bank_account_input['individualOwner']['lastName'], bank_account.last_name
  end

  def test_build_nonce_request_for_credit_card_without_address
    credit_card = credit_card('4111111111111111')
    response = @no_address_generator.send(:build_nonce_request, credit_card)
    parse_response = JSON.parse response
    assert_client_sdk_metadata(parse_response)
    assert_equal normalize_graph(parse_response['query']), normalize_graph(credit_card_query)
    assert_includes parse_response['variables']['input'], 'creditCard'

    credit_card_input = parse_response['variables']['input']['creditCard']

    assert_equal credit_card_input['number'], credit_card.number
    assert_equal credit_card_input['expirationYear'], credit_card.year.to_s
    assert_equal credit_card_input['expirationMonth'], credit_card.month.to_s.rjust(2, '0')
    assert_equal credit_card_input['cvv'], credit_card.verification_value
    assert_equal credit_card_input['cardholderName'], credit_card.name
  end

  def test_token_from
    credit_card = credit_card(number: 4111111111111111)
    c_token = @generator.send(:token_from, credit_card, token_credit_response)
    assert_match(/tokencc_/, c_token)

    bakn_account = check({ account_number: '4012000033330125', routing_number: '011000015' })
    b_token = @generator.send(:token_from, bakn_account, token_bank_response)
    assert_match(/tokenusbankacct_/, b_token)
  end

  def test_nil_token_from
    credit_card = credit_card(number: 4111111111111111)
    c_token = @generator.send(:token_from, credit_card, token_bank_response)
    assert_nil c_token

    bakn_account = check({ account_number: '4012000033330125', routing_number: '011000015' })
    b_token = @generator.send(:token_from, bakn_account, token_credit_response)
    assert_nil b_token
  end

  def assert_billing_address_mapping(request_input, payment_method)
    assert_equal request_input['billingAddress']['streetAddress'], @options[:billing_address][:address1]
    assert_equal request_input['billingAddress']['extendedAddress'], @options[:billing_address][:address2]

    if payment_method.is_a?(Check)
      assert_equal request_input['billingAddress']['city'], @options[:billing_address][:city]
      assert_equal request_input['billingAddress']['state'], @options[:billing_address][:state]
      assert_equal request_input['billingAddress']['zipCode'], @options[:billing_address][:zip]
    else
      assert_equal request_input['billingAddress']['locality'], @options[:billing_address][:city]
      assert_equal request_input['billingAddress']['region'], @options[:billing_address][:state]
      assert_equal request_input['billingAddress']['postalCode'], @options[:billing_address][:zip]
    end
  end

  def assert_client_sdk_metadata(parse_response)
    assert_equal parse_response['clientSdkMetadata']['platform'], 'web'
    assert_equal parse_response['clientSdkMetadata']['source'], 'client'
    assert_equal parse_response['clientSdkMetadata']['integration'], 'custom'
    assert_match(/\A[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}\z/i, parse_response['clientSdkMetadata']['sessionId'])
    assert_equal parse_response['clientSdkMetadata']['version'], '3.83.0'
  end

  private

  def normalize_graph(graph)
    graph.gsub(/\s+/, ' ').strip
  end

  def bank_account_query
    <<-GRAPHQL
    mutation TokenizeUsBankAccount($input: TokenizeUsBankAccountInput!) {
      tokenizeUsBankAccount(input: $input) {
        paymentMethod {
          id
          details {
            ... on UsBankAccountDetails {
              last4
            }
          }
        }
      }
    }
    GRAPHQL
  end

  def credit_card_query
    <<-GRAPHQL
    mutation TokenizeCreditCard($input: TokenizeCreditCardInput!) {
      tokenizeCreditCard(input: $input) {
        paymentMethod {
          id
          details {
            ... on CreditCardDetails {
              last4
            }
          }
        }
      }
    }
    GRAPHQL
  end

  def token_credit_response
    {
      'data' => {
        'tokenizeCreditCard' => {
          'paymentMethod' => {
            'id' => 'tokencc_bc_72n3ms_74wsn3_jp2vn4_gjj62v_g33',
            'details' => {
              'last4' => '1111'
            }
          }
        }
      },
      'extensions' => {
        'requestId' => 'a093afbb-42a9-4a85-973f-0ca79dff9ba6'
      }
    }
  end

  def token_bank_response
    {
      'data' => {
        'tokenizeUsBankAccount' => {
          'paymentMethod' => {
            'id' => 'tokenusbankacct_bc_zrg45z_7wz95v_nscrks_q4zpjs_5m7',
            'details' => {
              'last4' => '0125'
            }
          }
        }
      },
      'extensions' => {
        'requestId' => '769b26d5-27e4-4602-b51d-face8b6ffdd5'
      }
    }
  end
end
