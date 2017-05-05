require 'test_helper'

class RemoteMollieIdealIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @api_key = fixtures(:mollie_ideal)[:api_key]
  end

  def test_authorization
    assert_raises(ActiveMerchant::ResponseError) { MollieIdeal.retrieve_issuers('bad_api_key') }
  end

  def test_retrieve_issuers
    issuers = MollieIdeal.retrieve_issuers(@api_key)
    assert_equal [["TBM Bank", "ideal_TESTNL99"]], issuers
  end

  def test_create_payment_and_check_status
    create_response = MollieIdeal.create_payment(@api_key,
      :amount => BigDecimal.new('123.45'),
      :description => 'My order description',
      :redirectUrl => 'https://example.com/return',
      :method => 'ideal',
      :issuer => 'ideal_TESTNL99',
      :metadata => { :my_reference => 'unicorn' }
    )

    assert_equal 'open', create_response['status']
    assert_equal '123.45', create_response['amount']
    assert_equal 'My order description', create_response['description']
    assert_equal 'ideal', create_response['method']
    assert_equal 'unicorn', create_response['metadata']['my_reference']

    assert_equal 'https://example.com/return', create_response['links']['redirectUrl']
    redirect_uri = URI.parse(create_response['links']['paymentUrl'])
    assert_equal 'https', redirect_uri.scheme
    assert_equal 'www.mollie.nl', redirect_uri.host

    status_response = MollieIdeal.check_payment_status(@api_key, create_response['id'])
    assert_equal status_response, create_response
  end
end
