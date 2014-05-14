require 'test_helper'

class BalancedTest < Test::Unit::TestCase
  include CommStub

  def setup
    @marketplace_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO'

    @marketplace_uris = {
      'uri' => @marketplace_uri,
      'debits_uri' => '/debits',
      'cards_uri' => '/cards',
      'customer_uri' => '/customers',
      'refunds_uri' => '/refunds',
    }

    @gateway = BalancedGateway.new(
      login: 'e1c5ad38d1c711e1b36c026ba7e239a9',
      marketplace: @marketplace_uris
    )

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @invalid_card = credit_card('4222222222222220')
    @declined_card = credit_card('4444444444444448')

    @options = {
      email:  'john.buyer@example.org',
      billing_address: address,
      description: 'Shopify Purchase'
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
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(email: 'invalid_email'))
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

  def test_passing_appears_on_statement
    @gateway.expects(:ssl_request).times(4).returns(
      customers_response
    ).then.returns(
      cards_response
    ).then.returns(
      customers_response
    ).then.returns(
      appears_on_response
    )
    options = @options.merge(appears_on_statement_as: "Homer Electric")
    assert response = @gateway.purchase(@amount, @credit_card, options)

    assert_success response
    assert_equal "BAL*Homer Electric", response.params['debits'][0]['appears_on_statement_as']
  end

  def test_authorize_and_capture
    @gateway.expects(:ssl_request).times(5).returns(
      customers_response
    ).then.returns(
      cards_response
    ).then.returns(
      customers_response
    ).then.returns(
      holds_response
    ).then.returns(
      authorized_debits_response
    )

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
    @gateway.expects(:ssl_request).times(5).returns(
      customers_response
    ).then.returns(
      cards_response
    ).then.returns(
      customers_response
    ).then.returns(
      holds_response
    ).then.returns(
      authorized_partial_debits_response
    )

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
    @gateway.expects(:ssl_request).times(1).returns(
      method_not_allowed_response
    )

    assert response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_void_authorization
    @gateway.expects(:ssl_request).times(5).returns(
      customers_response
    ).then.returns(
      cards_response
    ).then.returns(
      customers_response
    ).then.returns(
      holds_response
    ).then.returns(
      voided_hold_response
    )

    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    number = auth.params["card_holds"][0]["href"]
    assert void = @gateway.void(number)
    assert_success void
    assert void.params["card_holds"][0]['voided_at']
  end

  def test_refund_purchase
    @gateway.expects(:ssl_request).times(5).returns(
      customers_response
    ).then.returns(
      cards_response
    ).then.returns(
      customers_response
    ).then.returns(
      debits_response
    ).then.returns(
      refunds_response
    )

    assert debit = @gateway.purchase(@amount, @credit_card, @options)
    assert_success debit

    debit_id = debit.params["debits"][0]["id"]
    capture_url = debit.params["links"]["debits.refunds"].gsub("{debits.id}", debit_id)

    assert refund = @gateway.refund(@amount, capture_url)
    assert_success refund
    assert_equal @amount, refund.params['refunds'][0]['amount']
  end

  def test_refund_partial_purchase
    @gateway.expects(:ssl_request).times(5).returns(
      customers_response
    ).then.returns(
      cards_response
    ).then.returns(
      customers_response
    ).then.returns(
      debits_response
    ).then.returns(
      partial_refunds_response
    )

    assert debit = @gateway.purchase(@amount, @credit_card, @options)
    assert_success debit

    debit_id = debit.params["debits"][0]["id"]
    capture_url = debit.params["links"]["debits.refunds"].gsub("{debits.id}", debit_id)

    assert refund = @gateway.refund(@amount / 2, capture_url)
    assert_success refund
    assert_equal @amount / 2, refund.params['refunds'][0]['amount']
  end

  def test_store
    @gateway.expects(:ssl_request).times(3).returns(
      customers_response
    ).then.returns(
      cards_response
    ).then.returns(
      customers_response
    )

    new_email_address = '%d@example.org' % Time.now
    assert response = @gateway.store(@credit_card, {
        email: new_email_address
    })
    assert_instance_of String, response.authorization
  end

  def test_invalid_login
    BalancedGateway.any_instance.expects(:ssl_get).returns(invalid_login_response)
    begin
      BalancedGateway.new(
        login: 'lol'
      )
    rescue BalancedGateway::Error => ex
      msg = ex.message
    else
      msg = nil
    end
    assert_equal 'Invalid login credentials supplied', msg
  end

  private

  def invalid_login_response
    %(
{
  "errors": [
    {
      "status": "Unauthorized",
      "category_code": "authentication-required",
      "description": "<p>The server could not verify that you are authorized to access the URL requested.  You either supplied the wrong credentials (e.g. a bad password), or your browser doesn't understand how to supply the credentials required.</p><p>In case you are allowed to request the document, please check your user-id and password and try again.</p> Your request id is OHM45edd6b0db7511e39cf202b12035401b.",
      "status_code": 401,
      "category_type": "permission",
      "request_id": "OHM45edd6b0db7511e39cf202b12035401b"
    }
  ]
}
    )
  end

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

  def authorized_debits_response
    <<-RESPONSE
{
  "debits": [
    {
      "status": "succeeded",
      "description": "Shopify Purchase",
      "links": {
        "customer": null,
        "source": "CC2uKKcUhaSFRrl2mnGPSbDO",
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

  def authorized_partial_debits_response
    <<-RESPONSE
{
  "debits": [
    {
      "status": "succeeded",
      "description": "Shopify Purchase",
      "links": {
        "customer": null,
        "source": "CC2uKKcUhaSFRrl2mnGPSbDO",
        "order": null,
        "dispute": null
      },
      "updated_at": "2014-02-06T23:19:29.690815Z",
      "created_at": "2014-02-06T23:19:28.709143Z",
      "transaction_number": "W250-112-1883",
      "failure_reason": null,
      "currency": "USD",
      "amount": 50,
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

  def appears_on_response
    <<-RESPONSE
{
  "debits": [
    {
      "status": "succeeded",
      "description": "Shopify Purchase",
      "links": {
        "customer": null,
        "source": "CC4SKo0WY3lhfWc6CgMyPo34",
        "order": null,
        "dispute": null
      },
      "updated_at": "2014-02-07T21:20:13.950392Z",
      "created_at": "2014-02-07T21:20:12.737821Z",
      "transaction_number": "W337-477-3752",
      "failure_reason": null,
      "currency": "USD",
      "amount": 100,
      "failure_reason_code": null,
      "meta": {},
      "href": "/debits/WD4UDDm6iqtYMEd21UBaa50H",
      "appears_on_statement_as": "BAL*Homer Electric",
      "id": "WD4UDDm6iqtYMEd21UBaa50H"
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

  def holds_response
    <<-RESPONSE
{
  "card_holds": [
    {
      "status": "succeeded",
      "description": "Shopify Purchase",
      "links": {
        "card": "CC2uKKcUhaSFRrl2mnGPSbDO",
        "debit": null
      },
      "updated_at": "2014-02-07T21:46:39.678439Z",
      "created_at": "2014-02-07T21:46:39.303526Z",
      "transaction_number": "HL343-028-3032",
      "expires_at": "2014-02-14T21:46:39.532363Z",
      "failure_reason": null,
      "currency": "USD",
      "amount": 100,
      "meta": {},
      "href": "/card_holds/HL2wPXf6ByqkLMiWGab7QRsq",
      "failure_reason_code": null,
      "voided_at": null,
      "id": "HL2wPXf6ByqkLMiWGab7QRsq"
    }
  ],
  "links": {
    "card_holds.events": "/card_holds/{card_holds.id}/events",
    "card_holds.card": "/resources/{card_holds.card}",
    "card_holds.debits": "/card_holds/{card_holds.id}/debits",
    "card_holds.debit": "/debits/{card_holds.debit}"
  }
}
RESPONSE
  end

  def method_not_allowed_response
    <<-RESPONSE
{
  "errors": [
    {
      "status": "Method Not Allowed",
      "category_code": "method-not-allowed",
      "description": "Your request id is OHMfaf5570a904211e3bcab026ba7f8ec28.",
      "status_code": 405,
      "category_type": "request",
      "request_id": "OHMfaf5570a904211e3bcab026ba7f8ec28"
    }
  ]
}
RESPONSE
  end

  def unauthorized_response
    <<-RESPONSE
{
  "errors": [
    {
      "status": "Unauthorized",
      "category_code": "authentication-required",
      "description": "<p>The server could not verify that you are authorized to access the URL requested.  You either supplied the wrong credentials (e.g. a bad password), or your browser doesn't understand how to supply the credentials required.</p><p>In case you are allowed to request the document, please check your user-id and password and try again.</p> Your request id is OHM56702560904311e3988c026ba7cd33d0.",
      "status_code": 401,
      "category_type": "permission",
      "request_id": "OHM56702560904311e3988c026ba7cd33d0"
    }
  ]
}
RESPONSE
  end

  def voided_hold_response
    <<-RESPONSE
{
  "card_holds": [
    {
      "status": "succeeded",
      "description": "Shopify Purchase",
      "links": {
        "card": "CC52ACcRnrG5eupOERKK4OAq",
        "debit": null
      },
      "updated_at": "2014-02-07T22:10:28.923304Z",
      "created_at": "2014-02-07T22:10:27.904233Z",
      "transaction_number": "HL728-165-8425",
      "expires_at": "2014-02-14T22:10:28.045745Z",
      "failure_reason": null,
      "currency": "USD",
      "amount": 100,
      "meta": {},
      "href": "/card_holds/HL54qindwhlErSujLo5IcP5J",
      "failure_reason_code": null,
      "voided_at": "2014-02-07T22:10:28.923308Z",
      "id": "HL54qindwhlErSujLo5IcP5J"
    }
  ],
  "links": {
    "card_holds.events": "/card_holds/{card_holds.id}/events",
    "card_holds.card": "/resources/{card_holds.card}",
    "card_holds.debits": "/card_holds/{card_holds.id}/debits",
    "card_holds.debit": "/debits/{card_holds.debit}"
  }
}
RESPONSE
  end

  def refunds_response
    <<-RESPONSE
{
  "links": {
    "refunds.dispute": "/disputes/{refunds.dispute}",
    "refunds.events": "/refunds/{refunds.id}/events",
    "refunds.debit": "/debits/{refunds.debit}",
    "refunds.order": "/orders/{refunds.order}"
  },
  "refunds": [
    {
      "status": "succeeded",
      "description": "Shopify Purchase",
      "links": {
        "debit": "WDAtJcbjh3EJLW0tp7CUxAk",
        "order": null,
        "dispute": null
      },
      "href": "/refunds/RFJ4N00zLaQFrfBkC8cbN68",
      "created_at": "2014-02-07T22:35:06.424855Z",
      "transaction_number": "RF424-240-3258",
      "updated_at": "2014-02-07T22:35:07.655276Z",
      "currency": "USD",
      "amount": 100,
      "meta": {},
      "id": "RFJ4N00zLaQFrfBkC8cbN68"
    }
  ]
}
RESPONSE
  end

  def partial_refunds_response
    <<-RESPONSE
{
  "links": {
    "refunds.dispute": "/disputes/{refunds.dispute}",
    "refunds.events": "/refunds/{refunds.id}/events",
    "refunds.debit": "/debits/{refunds.debit}",
    "refunds.order": "/orders/{refunds.order}"
  },
  "refunds": [
    {
      "status": "succeeded",
      "description": "Shopify Purchase",
      "links": {
        "debit": "WDAtJcbjh3EJLW0tp7CUxAk",
        "order": null,
        "dispute": null
      },
      "href": "/refunds/RFJ4N00zLaQFrfBkC8cbN68",
      "created_at": "2014-02-07T22:35:06.424855Z",
      "transaction_number": "RF424-240-3258",
      "updated_at": "2014-02-07T22:35:07.655276Z",
      "currency": "USD",
      "amount": 50,
      "meta": {},
      "id": "RFJ4N00zLaQFrfBkC8cbN68"
    }
  ]
}
RESPONSE
  end
end
