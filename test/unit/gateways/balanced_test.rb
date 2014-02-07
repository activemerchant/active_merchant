require 'test_helper'

class BalancedTest < Test::Unit::TestCase
  include CommStub

  def setup
    @marketplace_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO'

    marketplace_uris = {
      'uri' => @marketplace_uri,
      'debits_uri' => '/debits',
      'cards_uri' => '/cards',
      'customer_uri' => '/customers',
      'refunds_uri' => '/refunds',
    }

    @gateway = BalancedGateway.new(
      :login => 'e1c5ad38d1c711e1b36c026ba7e239a9',
      :marketplace => marketplace_uris
    )

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @invalid_card = credit_card('4222222222222220')
    @declined_card = credit_card('4444444444444448')

    @options = {
      :email =>  'john.buyer@example.org',
      :billing_address => address,
      :description => 'Shopify Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).times(4).returns(
      customers_response
    ).then.returns(
      cards_response
    ).then.returns(
      customers_response
    ).then.returns(
      debits_response
    )
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert_equal @amount, response.params['debits'][0]['amount']
  end

  def test_invalid_card
    @gateway.expects(:ssl_request).times(4).returns(
      customers_response
    ).then.returns(
      cards_response
    ).then.returns(
      declined_response
    )
    assert response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_match /Customer call bank/, response.message
  end

  def test_invalid_email
    @gateway.expects(:ssl_request).times(1).returns(
      bad_email_response
    )
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:email => 'invalid_email'))
    assert_failure response
    assert_match /Invalid field.*email/, response.message
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_request).times(4).returns(
      customers_response
    ).then.returns(
      cards_response
    ).then.returns(
      customers_response
    ).then.returns(
      account_frozen_response
    )

    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match /Account Frozen/, response.message
  end

=begin
  def test_passing_appears_on_statement
    options = @options.merge(appears_on_statement_as: "Homer Electric")
    assert response = @gateway.purchase(@amount, @credit_card, options)

    assert_success response
    assert_equal "BAL*Homer Electric", response.params['debits'][0]['appears_on_statement_as']
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction approved', auth.message

    hold_id = auth.params["card_holds"][0]["id"]
    capture_url = auth.params["links"]["card_holds.debits"].gsub("{card_holds.id}", hold_id)

    assert capture = @gateway.capture(amount, capture_url)
    assert_success capture
    assert_equal amount, capture.params['debits'][0]['amount']

    auth_card_id = auth.params['card_holds'][0]['links']['card']
    capture_source_id = capture.params['debits'][0]['links']['source']

    assert_equal auth_card_id, capture_source_id
  end

  def test_authorize_and_capture_partial
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction approved', auth.message

    hold_id = auth.params["card_holds"][0]["id"]
    capture_url = auth.params["links"]["card_holds.debits"].gsub("{card_holds.id}", hold_id)

    assert capture = @gateway.capture(amount / 2, capture_url)
    assert_success capture
    assert_equal amount / 2, capture.params['debits'][0]['amount']

    auth_card_id = auth.params['card_holds'][0]['links']['card']
    capture_source_id = capture.params['debits'][0]['links']['source']

    assert_equal auth_card_id, capture_source_id
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_void_authorization
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    number = auth.params["card_holds"][0]["href"]
    assert void = @gateway.void(number)
    assert_success void
    assert void.params["card_holds"][0]['voided_at']
  end

  def test_refund_purchase
    assert debit = @gateway.purchase(@amount, @credit_card, @options)
    assert_success debit

    debit_id = debit.params["debits"][0]["id"]
    capture_url = debit.params["links"]["debits.refunds"].gsub("{debits.id}", debit_id)

    assert refund = @gateway.refund(@amount, capture_url)
    assert_success refund
    assert_equal @amount, refund.params['refunds'][0]['amount']
  end

  def test_refund_partial_purchase
    assert debit = @gateway.purchase(@amount, @credit_card, @options)
    assert_success debit

    debit_id = debit.params["debits"][0]["id"]
    capture_url = debit.params["links"]["debits.refunds"].gsub("{debits.id}", debit_id)

    assert refund = @gateway.refund(@amount / 2, capture_url)
    assert_success refund
    assert_equal @amount / 2, refund.params['refunds'][0]['amount']
  end

  def test_store
    new_email_address = '%d@example.org' % Time.now
    assert response = @gateway.store(@credit_card, {
        :email => new_email_address
    })
    assert_instance_of String, response.authorization
  end

  def test_invalid_login
    begin
      BalancedGateway.new(
        :login => ''
      )
    rescue BalancedGateway::Error => ex
      msg = ex.message
    else
      msg = nil
    end
    assert_equal 'Invalid login credentials supplied', msg
  end
=end

  private

  def marketplace_response
    <<-RESPONSE
{
  "meta": {
    "last": "/marketplaces?limit=10&offset=0",
    "next": null,
    "href": "/marketplaces?limit=10&offset=0",
    "limit": 10,
    "offset": 0,
    "previous": null,
    "total": 1,
    "first": "/marketplaces?limit=10&offset=0"
  },
  "marketplaces": [
    {
      "in_escrow": 47202,
      "domain_url": "example.com",
      "name": "Test Marketplace",
      "links": {
        "owner_customer": "AC73SN17anKkjk6Y1sVe2uaq"
      },
      "href": "/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO",
      "created_at": "2012-07-19T17:33:51.974238Z",
      "support_email_address": "support@example.com",
      "updated_at": "2012-07-19T17:33:52.848042Z",
      "support_phone_number": "+16505551234",
      "production": false,
      "meta": {},
      "unsettled_fees": 0,
      "id": "TEST-MP73SaFdpQePv9dOaG5wXOGO"
    }
  ],
  "links": {
    "marketplaces.debits": "/debits",
    "marketplaces.reversals": "/reversals",
    "marketplaces.customers": "/customers",
    "marketplaces.credits": "/credits",
    "marketplaces.cards": "/cards",
    "marketplaces.card_holds": "/card_holds",
    "marketplaces.refunds": "/refunds",
    "marketplaces.owner_customer": "/customers/{marketplaces.owner_customer}",
    "marketplaces.transactions": "/transactions",
    "marketplaces.bank_accounts": "/bank_accounts",
    "marketplaces.callbacks": "/callbacks",
    "marketplaces.events": "/events"
  }
}
RESPONSE
  end

  def customers_response
    <<-RESPONSE
{
  "customers": [
    {
      "name": null,
      "links": {
        "source": null,
        "destination": null
      },
      "updated_at": "2014-02-06T23:19:25.522526Z",
      "created_at": "2014-02-06T23:19:25.347027Z",
      "dob_month": null,
      "id": "CUVdXCglg4YdG1dIIra1q4U",
      "phone": null,
      "href": "/customers/CUVdXCglg4YdG1dIIra1q4U",
      "merchant_status": "no-match",
      "meta": {},
      "dob_year": null,
      "address": {
        "city": null,
        "line2": null,
        "line1": null,
        "state": null,
        "postal_code": null,
        "country_code": null
      },
      "business_name": null,
      "ssn_last4": null,
      "email": "john.buyer@example.org",
      "ein": null
    }
  ],
  "links": {
    "customers.source": "/resources/{customers.source}",
    "customers.card_holds": "/customers/{customers.id}/card_holds",
    "customers.bank_accounts": "/customers/{customers.id}/bank_accounts",
    "customers.debits": "/customers/{customers.id}/debits",
    "customers.destination": "/resources/{customers.destination}",
    "customers.cards": "/customers/{customers.id}/cards",
    "customers.transactions": "/customers/{customers.id}/transactions",
    "customers.refunds": "/customers/{customers.id}/refunds",
    "customers.reversals": "/customers/{customers.id}/reversals",
    "customers.orders": "/customers/{customers.id}/orders",
    "customers.credits": "/customers/{customers.id}/credits"
  }
}
RESPONSE
  end

  def cards_response
    <<-RESPONSE
{
  "cards": [
    {
      "cvv_match": null,
      "links": {
        "customer": null
      },
      "name": "Longbob Longsen",
      "expiration_year": 2015,
      "avs_street_match": null,
      "is_verified": true,
      "created_at": "2014-02-06T23:19:27.146436Z",
      "cvv_result": null,
      "brand": "Visa",
      "number": "xxxxxxxxxxxx1111",
      "updated_at": "2014-02-06T23:19:27.146441Z",
      "id": "CCXfdppSxXOGzaMUHp9EQyI",
      "expiration_month": 9,
      "cvv": null,
      "meta": {},
      "href": "/cards/CCXfdppSxXOGzaMUHp9EQyI",
      "address": {
        "city": null,
        "line2": null,
        "line1": null,
        "state": null,
        "postal_code": null,
        "country_code": null
      },
      "fingerprint": "e0928a7fe2233bf6697413f663b3d94114358e6ac027fcd58ceba0bb37f05039",
      "avs_postal_match": null,
      "avs_result": null
    }
  ],
  "links": {
    "cards.card_holds": "/cards/{cards.id}/card_holds",
    "cards.customer": "/customers/{cards.customer}",
    "cards.debits": "/cards/{cards.id}/debits"
  }
}
RESPONSE
  end

  def debits_response
    <<-RESPONSE
{
  "debits": [
    {
      "status": "succeeded",
      "description": "Shopify Purchase",
      "links": {
        "customer": null,
        "source": "CCXfdppSxXOGzaMUHp9EQyI",
        "order": null,
        "dispute": null
      },
      "updated_at": "2014-02-06T23:19:29.690815Z",
      "created_at": "2014-02-06T23:19:28.709143Z",
      "transaction_number": "W250-112-1883",
      "failure_reason": null,
      "currency": "USD",
      "amount": 100,
      "failure_reason_code": null,
      "meta": {},
      "href": "/debits/WDYZhc3mWCkxvOwIokeUz6M",
      "appears_on_statement_as": "BAL*example.com",
      "id": "WDYZhc3mWCkxvOwIokeUz6M"
    }
  ],
  "links": {
    "debits.customer": "/customers/{debits.customer}",
    "debits.dispute": "/disputes/{debits.dispute}",
    "debits.source": "/resources/{debits.source}",
    "debits.order": "/orders/{debits.order}",
    "debits.refunds": "/debits/{debits.id}/refunds",
    "debits.events": "/debits/{debits.id}/events"
  }
}
RESPONSE
  end

  def declined_response
    <<-RESPONSE
{
  "errors": [
    {
      "status": "Payment Required",
      "category_code": "card-declined",
      "additional": "Customer call bank",
      "status_code": 402,
      "category_type": "banking",
      "extras": {},
      "request_id": "OHMc8d80eb4903011e390c002a1fe53e539",
      "description": "R530: Customer call bank. Your request id is OHMc8d80eb4903011e390c002a1fe53e539."
    }
  ]
}
RESPONSE
  end

  def bad_email_response
    <<-'RESPONSE'
{
  "errors": [
    {
      "status": "Bad Request",
      "category_code": "request",
      "additional": null,
      "status_code": 400,
      "category_type": "request",
      "extras": {
        "email": "\"invalid_email\" must be a valid email address as specified by RFC-2822"
      },
      "request_id": "OHM9107a4bc903111e390c002a1fe53e539",
      "description": "Invalid field [email] - \"invalid_email\" must be a valid email address as specified by RFC-2822 Your request id is OHM9107a4bc903111e390c002a1fe53e539."
    }
  ]
}
RESPONSE
  end

  def account_frozen_response
    <<-RESPONSE
{
  "errors": [
    {
      "status": "Payment Required",
      "category_code": "card-declined",
      "additional": "Account Frozen",
      "status_code": 402,
      "category_type": "banking",
      "extras": {},
      "request_id": "OHMec50b6be903c11e387cb026ba7cac9da",
      "description": "R758: Account Frozen. Your request id is OHMec50b6be903c11e387cb026ba7cac9da."
    }
  ],
  "links": {
    "debits.customer": "/customers/{debits.customer}",
    "debits.dispute": "/disputes/{debits.dispute}",
    "debits.source": "/resources/{debits.source}",
    "debits.order": "/orders/{debits.order}",
    "debits.refunds": "/debits/{debits.id}/refunds",
    "debits.events": "/debits/{debits.id}/events"
  },
  "debits": [
    {
      "status": "failed",
      "description": "Shopify Purchase",
      "links": {
        "customer": null,
        "source": "CC7a41DYIaSSyGoau6rZ8VcG",
        "order": null,
        "dispute": null
      },
      "updated_at": "2014-02-07T21:15:10.107464Z",
      "created_at": "2014-02-07T21:15:09.206335Z",
      "transaction_number": "W202-883-1157",
      "failure_reason": "R758: Account Frozen.",
      "currency": "USD",
      "amount": 100,
      "failure_reason_code": "card-declined",
      "meta": {},
      "href": "/debits/WD7cjQ5gizGWMDWbxDndgm7w",
      "appears_on_statement_as": "BAL*example.com",
      "id": "WD7cjQ5gizGWMDWbxDndgm7w"
    }
  ]
}
RESPONSE
  end
end
