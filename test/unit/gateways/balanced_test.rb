require 'test_helper'

class BalancedTest < Test::Unit::TestCase
  include CommStub

  def setup
    @marketplace_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO'

    marketplace_uris = {
      'uri' => @marketplace_uri,
      'holds_uri' => @marketplace_uri + '/holds',
      'debits_uri' => @marketplace_uri + '/debits',
      'cards_uri' => @marketplace_uri + '/cards',
      'accounts_uri' => @marketplace_uri + '/accounts',
      'refunds_uri' => @marketplace_uri + '/refunds',
    }

    @gateway = BalancedGateway.new(
      :login => 'e1c5ad38d1c711e1b36c026ba7e239a9',
      :marketplace => marketplace_uris
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :email =>  'john.buyer@example.org',
      :billing_address => address,
      :description => 'Shopify Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).times(4).returns(
        successful_account_response
    ).then.returns(
        successful_card_response
    ).then.returns(
        successful_account_response
    ).then.returns(
        successful_purchase_response
    )

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/debits/WD2x6vLS7RzHYEcdymqRyNAO', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_existing_account
    @gateway.expects(:ssl_request).times(4).returns(
        failed_account_response
    ).then.returns(
        successful_card_response
    ).then.returns(
        successful_account_response
    ).then.returns(
        successful_purchase_response
    )

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/debits/WD2x6vLS7RzHYEcdymqRyNAO', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_existing_account_uri
    @gateway.expects(:ssl_request).times(3).returns(
        successful_card_response
    ).then.returns(
        successful_account_response
    ).then.returns(
        successful_purchase_response
    )
    options = @options.clone
    options[:account_uri] = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC58ZKWuGoyQEnDy9ENGRGSq'
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/debits/WD2x6vLS7RzHYEcdymqRyNAO', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_existing_card
    @gateway.expects(:ssl_request).times(1).returns(
        successful_purchase_response
    )
    options = @options.clone
    credit_card = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/cards
/CC6r6kLUcxW3MxG3AmZoiuTf'
    options[:account_uri] = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC58ZKWuGoyQEnDy9ENGRGSq'
    assert response = @gateway.purchase(@amount, credit_card, options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/debits/WD2x6vLS7RzHYEcdymqRyNAO', response.authorization
    assert response.test?
  end

  def test_bad_email
    @gateway.stubs(:ssl_request).returns(failed_account_response_bad_email).then.returns(successful_card_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_match /must be a valid email address/, response.message
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_request).times(4).returns(
        successful_account_response
    ).then.returns(
        successful_card_response
    ).then.returns(
        successful_account_response
    ).then.returns(
        failed_purchase_response
    )

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorization
    @gateway.expects(:ssl_request).times(4).returns(
        successful_account_response
    ).then.returns(
        successful_card_response
    ).then.returns(successful_account_response).then.returns(
        successful_hold_response
    )
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/holds/HL7dYMhpVBcqAYqxLF5mZtQ5', response.authorization
    assert response.test?
  end

  def test_unsuccessful_authorization
    @gateway.expects(:ssl_request).times(4).returns(
        successful_account_response
    ).then.returns(
        successful_card_response
    ).then.returns(
        successful_account_response
    ).then.returns(
        failed_purchase_response
    )

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end

  def test_successful_authorization_capture
    @gateway.expects(:ssl_request).times(1).returns(
        successful_purchase_response
    )
    hold_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/holds/HL7dYMhpVBcqAYqxLF5mZtQ5'
    assert response = @gateway.capture(nil, hold_uri)  # captures the full amount
    assert_instance_of Response, response
    assert_success response
    assert_equal '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/debits/WD2x6vLS7RzHYEcdymqRyNAO', response.authorization
    assert response.test?
  end

  def test_successful_authorization_capture_with_on_behalf_of_uri
    @gateway.expects(:ssl_request).times(1).returns(
        successful_purchase_response
    )

    hold_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/holds/HL7dYMhpVBcqAYqxLF5mZtQ5'
    on_behalf_of_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC73SN17anKkjk6Y1sVe2uaq'

    response = stub_comms do
      @gateway.capture(nil, hold_uri, :on_behalf_of_uri => on_behalf_of_uri)
    end.check_request do |endpoint, data, headers|
      assert_match(/on_behalf_of_uri=\/v1\/marketplaces\/TEST-MP73SaFdpQePv9dOaG5wXOGO\/accounts\/AC73SN17anKkjk6Y1sVe2uaq/, data)
    end.respond_with(successful_purchase_response)

    assert_instance_of Response, response
    assert_success response
    assert_equal '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/debits/WD2x6vLS7RzHYEcdymqRyNAO', response.authorization
    assert response.test?
  end

  def test_unsuccessful_authorization_capture
    @gateway.expects(:ssl_request).times(1).returns(
        failed_purchase_response
    )
    hold_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/holds/HL7dYMhpVBcqAYqxLF5mZtQ5'
    assert response = @gateway.capture(0, hold_uri)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end

  def test_void_authorization_success
    @gateway.expects(:ssl_request).times(1).returns(
        void_hold_response
    )
    hold_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/holds/HL7dYMhpVBcqAYqxLF5mZtQ5'
    response = @gateway.void(hold_uri)
    assert_instance_of Response, response
    assert_success response
    assert_equal hold_uri, response.authorization
    assert response.test?
  end

  def test_void_authorization_failure
    @gateway.expects(:ssl_request).times(1).returns(
        void_hold_response_failure
    )
    hold_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/holds/HL7dYMhpVBcqAYqxLF5mZtQ5'
    assert response = @gateway.void(hold_uri)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end

  def test_refund_purchase
    @gateway.expects(:ssl_request).times(1).returns(
        successful_refund_response
    )

    debit_uri = '/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/debits/WD2Nkre6GkWAV1A52YgLWEkh'
    refund_uri = '/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/refunds/RF3GhhG5I3AgrjjXsdkRFQDA'
    assert refund = @gateway.refund(@amount, debit_uri)
    assert_instance_of Response, refund
    assert_success refund
    assert refund.test?
    assert_equal refund.authorization, refund_uri
  end

  def test_refund_purchase_failure
    @gateway.expects(:ssl_request).times(1).returns(
        failed_refund_response
    )

    debit_uri = '/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/debits/WD2Nkre6GkWAV1A52YgLWEkh'
    assert refund = @gateway.refund(@amount, debit_uri)
    assert_instance_of Response, refund
    assert_failure refund
    assert refund.test?
  end

  def test_deprecated_refund_purchase
    assert_deprecation_warning("Calling the refund method without an amount parameter is deprecated and will be removed in a future version.", @gateway) do
      @gateway.expects(:ssl_request).times(1).returns(
          successful_refund_response
      )

      debit_uri = '/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/debits/WD2Nkre6GkWAV1A52YgLWEkh'
      refund_uri = '/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/refunds/RF3GhhG5I3AgrjjXsdkRFQDA'
      assert refund = @gateway.refund(debit_uri)
      assert_instance_of Response, refund
      assert_success refund
      assert refund.test?
      assert_equal refund.authorization, refund_uri
    end
  end

  def test_refund_with_nil_debit_uri
    @gateway.expects(:ssl_request).times(1).returns(
        failed_refund_response
    )

    assert refund = @gateway.refund(nil, nil)
    assert_instance_of Response, refund
    assert_failure refund
  end

  def test_store
    @gateway.expects(:ssl_request).times(3).returns(
        successful_account_response  # create account
    ).then.returns(
        successful_card_response     # create card
    ).then.returns(
        successful_account_response  # associate card to account
    )

    card_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/cards/CC6r6kLUcxW3MxG3AmZoiuTf'
    account_uri = '/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu'
    assert response = @gateway.store(@credit_card, {
        :email=>'john.buyer@example.org'
    })
    assert_instance_of Response, response
    assert_success response
    assert_equal "#{card_uri};#{account_uri}", response.authorization
  end

  def test_ensure_does_not_respond_to_credit
    assert !@gateway.respond_to?(:credit)
  end

  def test_ensure_does_not_respond_to_unstore
    assert !@gateway.respond_to?(:unstore)
  end

  private

  def marketplace_response
    <<-RESPONSE
{
  "first_uri": "/v1/marketplaces?limit=10&offset=0",
  "items": [
    {
      "in_escrow": 5200,
      "support_phone_number": "+16505551234",
      "domain_url": "example.com",
      "name": "Test Marketplace",
      "transactions_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/transactions",
      "support_email_address": "support@example.com",
      "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO",
      "bank_accounts_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/bank_accounts",
      "owner_account": {
        "holds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC73SN17anKkjk6Y1sVe2uaq/holds",
        "name": "William Henry Cavendish III",
        "roles": [
          "merchant",
          "buyer"
        ],
        "created_at": "2012-07-19T17:33:51.977484Z",
        "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC73SN17anKkjk6Y1sVe2uaq",
        "bank_accounts_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC73SN17anKkjk6Y1sVe2uaq/bank_accounts",
        "refunds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC73SN17anKkjk6Y1sVe2uaq/refunds",
        "meta": {},
        "debits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC73SN17anKkjk6Y1sVe2uaq/debits",
        "transactions_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC73SN17anKkjk6Y1sVe2uaq/transactions",
        "email_address": "whc@example.org",
        "id": "AC73SN17anKkjk6Y1sVe2uaq",
        "credits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC73SN17anKkjk6Y1sVe2uaq/credits",
        "cards_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC73SN17anKkjk6Y1sVe2uaq/cards"
      },
      "refunds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/refunds",
      "meta": {},
      "debits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/debits",
      "holds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/holds",
      "accounts_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts",
      "id": "TEST-MP73SaFdpQePv9dOaG5wXOGO",
      "credits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/credits",
      "cards_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/cards"
    }
  ],
  "previous_uri": null,
  "uri": "/v1/marketplaces?limit=10&offset=0",
  "limit": 10,
  "offset": 0,
  "total": 1,
  "next_uri": null,
  "last_uri": "/v1/marketplaces?limit=10&offset=0"
}
    RESPONSE
  end

  # raw responses from gateway here
  def successful_account_response
    <<-RESPONSE
{
    "holds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/holds",
    "name": null,
    "roles": [
      "buyer"
    ],
    "created_at": "2012-06-08T02:00:18.233961Z",
    "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu",
    "bank_accounts_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/bank_accounts",
    "refunds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/refunds",
    "meta": {},
    "debits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/debits",
    "transactions_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/transactions",
    "email_address": "will@example.org",
    "id": "AC5quPICW5qEHXac1KnjKGYu",
    "credits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/credits",
    "cards_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/cards"
}
    RESPONSE
  end

  def failed_account_response
    <<-RESPONSE
{
  "status": "Conflict",
  "category_code": "duplicate-email-address",
  "additional": null,
  "status_code": 409,
  "category_type": "logical",
  "extras": {
    "account_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC58ZKWuGoyQEnDy9ENGRGSq"
  },
  "request_id": "OHMc3f6135cd1fd11e19f1e026ba7e5e72e",
  "description": "Account with email address 'john.buyer@example.org' already exists. Your request id is OHMc3f6135cd1fd11e19f1e026ba7e5e72e."
}
    RESPONSE
  end

  def failed_account_response_bad_email
    <<-RESPONSE
{
  "status": "Bad Request",
  "category_code": "request",
  "additional": null,
  "status_code": 400,
  "category_type": "request",
  "extras": {
    "email_address": "invalid_email must be a valid email address as specified by RFC-2822"
  },
  "request_id": "OHM417b4e7ad9e411e2893c026ba7c1aba6",
  "description": "Invalid field [email_address] - invalid_email must be a valid email address as specified by RFC-2822 Your request id is OHM417b4e7ad9e411e2893c026ba7c1aba6."
}
    RESPONSE
  end

  def successful_card_response
    <<-RESPONSE
    {
        "card_type": "visa",
        "account": null,
    "country_code": "USA",
        "expiration_year": 2013,
        "created_at": "2012-07-19T23:31:12.334686Z",
        "brand": "Visa",
        "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/cards/CC6r6kLUcxW3MxG3AmZoiuTf",
        "expiration_month": 9,
        "is_valid": true,
    "meta": {},
        "last_four": 4242,
        "postal_code": "K1C2N6",
        "id": "CC6r6kLUcxW3MxG3AmZoiuTf",
        "street_address": "1234 My Street Apt 1",
        "name": "Longbob Longsen"
    }
    RESPONSE
  end

  def void_hold_response_failure
    <<-RESPONSE
{
  "status": "Conflict",
  "category_code": "cannot-void-authorization",
  "additional": null,
  "status_code": 409,
  "category_type": "logical",
  "extras": {},
  "request_id": "OHMe8da23e0d20511e1af4e026ba7e5e72e",
  "description": "Hold already captured or voided. Your request id is OHMe8da23e0d20511e1af4e026ba7e5e72e."
}
    RESPONSE
  end

  def void_hold_response
    <<-RESPONSE
{
  "account": {
    "holds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/holds",
    "name": null,
    "roles": [
      "buyer"
    ],
    "created_at": "2012-06-08T02:00:18.233961Z",
    "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu",
    "bank_accounts_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/bank_accounts",
    "refunds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/refunds",
    "meta": {},
    "debits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/debits",
    "transactions_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/transactions",
    "email_address": "will@example.org",
    "id": "AC5quPICW5qEHXac1KnjKGYu",
    "credits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/credits",
    "cards_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/cards"
  },
  "fee": 35,
  "description": null,
  "amount": 200,
  "created_at": "2012-06-08T02:01:57.356366Z",
  "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/holds/HL7dYMhpVBcqAYqxLF5mZtQ5",
  "expires_at": "2012-06-15T02:01:57.316184Z",
  "source": {
    "expiration_month": 12,
    "name": null,
    "expiration_year": 2020,
    "brand": "MasterCard",
    "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/cards/CCZCMxRRAvPt2K4uU460EFX",
    "id": "CCZCMxRRAvPt2K4uU460EFX",
    "card_type": "mastercard",
    "is_valid": true,
    "last_four": 5100,
    "created_at": "2012-06-08T01:56:13.845267Z"
  },
  "is_void": true,
  "meta": {},
  "debit": null,
  "id": "HL7dYMhpVBcqAYqxLF5mZtQ5"
}

    RESPONSE
  end

  def successful_hold_response
    <<-RESPONSE
{
  "account": {
    "holds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/holds",
    "name": null,
    "roles": [
      "buyer"
    ],
    "created_at": "2012-06-08T02:00:18.233961Z",
    "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu",
    "bank_accounts_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/bank_accounts",
    "refunds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/refunds",
    "meta": {},
    "debits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/debits",
    "transactions_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/transactions",
    "email_address": "will@example.org",
    "id": "AC5quPICW5qEHXac1KnjKGYu",
    "credits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/credits",
    "cards_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/cards"
  },
  "fee": 35,
  "description": null,
  "amount": 200,
  "created_at": "2012-06-08T02:01:57.356366Z",
  "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/holds/HL7dYMhpVBcqAYqxLF5mZtQ5",
  "expires_at": "2012-06-15T02:01:57.316184Z",
  "source": {
    "expiration_month": 12,
    "name": null,
    "expiration_year": 2020,
    "brand": "MasterCard",
    "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/cards/CCZCMxRRAvPt2K4uU460EFX",
    "id": "CCZCMxRRAvPt2K4uU460EFX",
    "card_type": "mastercard",
    "is_valid": true,
    "last_four": 5100,
    "created_at": "2012-06-08T01:56:13.845267Z"
  },
  "is_void": false,
  "meta": {},
  "debit": null,
  "id": "HL7dYMhpVBcqAYqxLF5mZtQ5"
}

    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
{
  "account": {
    "holds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/holds",
    "name": null,
    "roles": [
      "buyer"
    ],
    "created_at": "2012-06-08T02:00:18.233961Z",
    "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu",
    "bank_accounts_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/bank_accounts",
    "refunds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/refunds",
    "meta": {},
    "debits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/debits",
    "transactions_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/transactions",
    "email_address": "will@example.org",
    "id": "AC5quPICW5qEHXac1KnjKGYu",
    "credits_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/credits",
    "cards_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/cards"
  },
  "fee": 5,
  "description": null,
  "refunds_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/debits/WD2x6vLS7RzHYEcdymqRyNAO/refunds",
  "amount": 150,
  "created_at": "2012-06-08T02:11:57.737829Z",
  "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/debits/WD2x6vLS7RzHYEcdymqRyNAO",
  "source": {
    "expiration_month": 12,
    "name": null,
    "expiration_year": 2020,
    "brand": "MasterCard",
    "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/cards/CCZCMxRRAvPt2K4uU460EFX",
    "id": "CCZCMxRRAvPt2K4uU460EFX",
    "card_type": "mastercard",
    "is_valid": true,
    "last_four": 5100,
    "created_at": "2012-06-08T01:56:13.845267Z"
  },
  "transaction_number": "W615-916-0468",
  "meta": {},
  "appears_on_statement_as": "example.com",
  "hold": {
    "fee": 35,
    "description": null,
    "created_at": "2012-06-08T02:01:57.356366Z",
    "is_void": false,
    "expires_at": "2012-06-15T02:01:57.316184Z",
    "uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/holds/HL7dYMhpVBcqAYqxLF5mZtQ5",
    "amount": 200,
    "meta": {},
    "account_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu",
    "source_uri": "/v1/marketplaces/TEST-MP73SaFdpQePv9dOaG5wXOGO/accounts/AC5quPICW5qEHXac1KnjKGYu/cards/CCZCMxRRAvPt2K4uU460EFX",
    "id": "HL7dYMhpVBcqAYqxLF5mZtQ5"
  },
  "id": "WD2x6vLS7RzHYEcdymqRyNAO",
  "available_at": "2012-06-08T02:11:57.670850Z"
}
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
{
  "status":"Bad Request",
  "category_code": "request",
  "additional": null,
  "status_code": 400,
  "category_type": "request",
  "extras": {},
  "request_id": "OHM7ba062c4d1ee11e1a63d026ba7e5e72e",
  "description": "Invalid field [amount] - 0 must be >= 50 Your request id is OHM7ba062c4d1ee11e1a63d026ba7e5e72e."
}
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
{
  "account": {
    "holds_uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/accounts/AC5quPICW5qEHXac1KnjKGYu/holds",
    "name": null,
    "roles": [
      "buyer"
    ],
    "created_at": "2012-06-08T02:00:18.233961Z",
    "uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/accounts/AC5quPICW5qEHXac1KnjKGYu",
    "bank_accounts_uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/accounts/AC5quPICW5qEHXac1KnjKGYu/bank_accounts",
    "refunds_uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/accounts/AC5quPICW5qEHXac1KnjKGYu/refunds",
    "meta": {},
    "debits_uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/accounts/AC5quPICW5qEHXac1KnjKGYu/debits",
    "transactions_uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/accounts/AC5quPICW5qEHXac1KnjKGYu/transactions",
    "email_address": "will@example.org",
    "id": "AC5quPICW5qEHXac1KnjKGYu",
    "credits_uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/accounts/AC5quPICW5qEHXac1KnjKGYu/credits",
    "cards_uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/accounts/AC5quPICW5qEHXac1KnjKGYu/cards"
  },
  "fee": -5,
  "description": null,
  "amount": 150,
  "created_at": "2012-07-20T19:16:56.921554Z",
  "uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/refunds/RF3GhhG5I3AgrjjXsdkRFQDA",
  "transaction_number": "RF589-096-4953",
  "meta": {},
  "debit": {
    "hold_uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/holds/HL2N2aMGzHdZ5xRocCqiLxKp",
    "fee": 5,
    "description": null,
    "source_uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/accounts/AC5quPICW5qEHXac1KnjKGYu/cards/CC6gGmoZ21ApTyng82GY6RsZ",
    "created_at": "2012-07-20T19:16:08.077620Z",
    "transaction_number": "W543-770-7869",
    "uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/debits/WD2Nkre6GkWAV1A52YgLWEkh",
    "refunds_uri": "/v1/marketplaces/TEST-MP6IEymJ6ynwnSoqJQnUTacN/debits/WD2Nkre6GkWAV1A52YgLWEkh/refunds",
    "amount": 150,
    "meta": {},
    "appears_on_statement_as": "example.com",
    "id": "WD2Nkre6GkWAV1A52YgLWEkh",
    "available_at": "2012-07-20T19:16:07.990758Z"
  },
  "appears_on_statement_as": "example.com",
  "id": "RF3GhhG5I3AgrjjXsdkRFQDA"
}
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
{
  "status": "Bad Request",
  "category_code": "request",
  "additional": null,
  "status_code": 400,
  "category_type": "request",
  "extras": {},
  "request_id": "OHM6b91d56ed29f11e18991026ba7e239a9",
  "description": "Invalid field [amount] - 170 must be <= 150 Your request id is OHM6b91d56ed29f11e18991026ba7e239a9."
}
    RESPONSE
  end
end
