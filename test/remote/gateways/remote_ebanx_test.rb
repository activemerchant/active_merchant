require 'test_helper'

class RemoteEbanxTest < Test::Unit::TestCase
  def setup
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('5102026827345142')
    @options = {
      billing_address: address({
                                 address1: '1040 Rua E',
                                 city: 'Maracanaú',
                                 state: 'CE',
                                 zip: '61919-230',
                                 country: 'BR',
                                 phone: '8522847035'
                               }),
      order_id: generate_unique_id,
      document: '853.513.468-93',
      device_id: '34c376b2767',
      metadata: {
        metadata_1: 'test',
        metadata_2: 'test2'
      },
      tags: EbanxGateway::TAGS,
      soft_descriptor: 'ActiveMerchant',
      email: 'neymar@test.com'
    }

    @hiper_card = credit_card('6062825624254001')
    @elo_card = credit_card('6362970000457013')
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "expecting successful purchase for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      response = @gateway.purchase(@amount, @credit_card, @options)
      assert_success response
      assert_equal 'Accepted', response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "expecting successful purchase with hiper card for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      response = @gateway.purchase(@amount, @hiper_card, @options)
      assert_success response
      assert_equal 'Accepted', response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "expecting successful purchase with elo card for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))

      response = @gateway.purchase(@amount, @elo_card, @options)
      assert_success response
      assert_equal 'Accepted', response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "expecting successful purchase with more options for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      options = @options.merge({
                                 order_id: generate_unique_id,
                                 ip: '127.0.0.1',
                                 email: 'joe@example.com',
                                 birth_date: '10/11/1980',
                                 person_type: 'personal'
                               })
      response = @gateway.purchase(@amount, @credit_card, options)
      assert_success response
      assert_equal 'Accepted', response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful purchase passing processing type in header for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      @options.merge({ processing_type: 'local' })
      @options.merge({ integration_key: 'test_ik_rFzG7hylTozF9EgaUnC_Bg' })
      response = @gateway.purchase(@amount, @credit_card, @options)

      assert_success response
      assert_equal 'Accepted', response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful purchase as brazil business with responsible fields for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      options = @options.update(document: '32593371000110',
                                person_type: 'business',
                                responsible_name: 'Business Person',
                                responsible_document: '32593371000111',
                                responsible_birth_date: '1/11/1975')

      response = @gateway.purchase(@amount, @credit_card, options)
      assert_success response
      assert_equal 'Accepted', response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful purchase as colombian for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      options = @options.merge({
                                 order_id: generate_unique_id,
                                 ip: '127.0.0.1',
                                 email: 'jose@example.com.co',
                                 birth_date: '10/11/1980',
                                 billing_address: address({
                                                            address1: '1040 Rua E',
                                                            city: 'Medellín',
                                                            state: 'AN',
                                                            zip: '29269',
                                                            country: 'CO',
                                                            phone_number: '8522847035'
                                                          })
                               })

      response = @gateway.purchase(500, @credit_card, options)
      assert_success response
      assert_equal 'Accepted', response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "failed purchase for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      response = @gateway.purchase(@amount, @declined_card, @options)
      assert_failure response
      assert_equal 'Invalid card or card type', response.message
      assert_equal 'NOK', response.error_code
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful authorize and capture for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      auth = @gateway.authorize(@amount, @credit_card, @options)
      assert_success auth
      assert_equal 'Accepted', auth.message

      assert capture = @gateway.capture(@amount, auth.authorization, @options)
      assert_success capture
      assert_equal 'Accepted', capture.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "failed authorize for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      response = @gateway.authorize(@amount, @declined_card, @options)
      assert_failure response
      assert_equal 'Invalid card or card type', response.message
      assert_equal 'NOK', response.error_code
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "failed_authorize_no_email for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      response = @gateway.authorize(@amount, @credit_card, @options.except(:email))
      assert_failure response
      assert_equal 'Field payment.email is required', response.message
      assert_equal 'BP-DR-15', response.error_code
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful partial capture when include capture amount is not passed for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      auth = @gateway.authorize(@amount, @credit_card, @options)
      assert_success auth

      assert capture = @gateway.capture(@amount - 1, auth.authorization)
      assert_success capture
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    # Partial capture is only available in Brazil and the EBANX Integration Team must be contacted to enable
    test "failed partial capture when include capture amount is passed for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      auth = @gateway.authorize(@amount, @credit_card, @options)
      assert_success auth

      assert capture = @gateway.capture(@amount - 1, auth.authorization, @options.merge(include_capture_amount: true))
      assert_failure capture
      assert_equal 'Partial capture not available', capture.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "failedcapture for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      response = @gateway.capture(@amount, '')
      assert_failure response
      assert_equal 'Parameters hash or merchant_payment_code not informed', response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful refund for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      purchase = @gateway.purchase(@amount, @credit_card, @options)
      assert_success purchase

      refund_options = @options.merge({ description: 'full refund' })
      assert refund = @gateway.refund(@amount, purchase.authorization, refund_options)
      assert_success refund
      assert_equal 'Accepted', refund.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "partial refund for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      purchase = @gateway.purchase(@amount, @credit_card, @options)
      assert_success purchase

      refund_options = @options.merge(description: 'refund due to returned item')
      assert refund = @gateway.refund(@amount - 1, purchase.authorization, refund_options)
      assert_success refund
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "failed refund for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      response = @gateway.refund(@amount, '')
      assert_failure response
      assert_match('Parameter hash not informed', response.message)
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful void for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      auth = @gateway.authorize(@amount, @credit_card, @options)
      assert_success auth

      assert void = @gateway.void(auth.authorization)
      assert_success void
      assert_equal 'Accepted', void.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "failed void for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      response = @gateway.void('')
      assert_failure response
      assert_equal 'Parameters hash or merchant_payment_code not informed', response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful store and purchase for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      store = @gateway.store(@credit_card, @options)
      assert_success store

      assert purchase = @gateway.purchase(@amount, store.authorization, @options)
      assert_success purchase
      assert_equal 'Accepted', purchase.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful store and purchase as brazil business for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      options = @options.update(document: '32593371000110',
                                person_type: 'business',
                                responsible_name: 'Business Person',
                                responsible_document: '32593371000111',
                                responsible_birth_date: '1/11/1975')

      store = @gateway.store(@credit_card, options)
      assert_success store
      assert_equal store.authorization.split('|')[1], 'visa'

      assert purchase = @gateway.purchase(@amount, store.authorization, options)
      assert_success purchase
      assert_equal 'Accepted', purchase.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful store and purchase as brazil business with hipercard for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))

      options = @options.update(document: '32593371000110',
                                person_type: 'business',
                                responsible_name: 'Business Person',
                                responsible_document: '32593371000111',
                                responsible_birth_date: '1/11/1975')

      store = @gateway.store(@hiper_card, options)
      assert_success store
      assert_equal store.authorization.split('|')[1], 'hipercard'

      assert purchase = @gateway.purchase(@amount, store.authorization, options)
      assert_success purchase
      assert_equal 'Accepted', purchase.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "failed purchase with stored card for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      store = @gateway.store(@declined_card, @options)
      assert_success store

      assert purchase = @gateway.purchase(@amount, store.authorization, @options)
      assert_failure purchase
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful verify for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      response = @gateway.verify(@credit_card, @options)
      assert_success response
      assert_match %r{Accepted}, response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful verify for chile for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      options = @options.merge({
                                 order_id: generate_unique_id,
                                 ip: '127.0.0.1',
                                 email: 'jose@example.com.cl',
                                 birth_date: '10/11/1980',
                                 billing_address: address({
                                                            address1: '1040 Rua E',
                                                            city: 'Medellín',
                                                            state: 'AN',
                                                            zip: '29269',
                                                            country: 'CL',
                                                            phone_number: '8522847035'
                                                          })
                               })

      response = @gateway.verify(@credit_card, options)
      assert_success response
      assert_match %r{Accepted}, response.message
    end
  end
  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful verify for mexico for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      options = @options.merge({
                                 order_id: generate_unique_id,
                                 ip: '127.0.0.1',
                                 email: 'joao@example.com.mx',
                                 birth_date: '10/11/1980',
                                 billing_address: address({
                                                            address1: '1040 Rua E',
                                                            city: 'Toluca de Lerdo',
                                                            state: 'MX',
                                                            zip: '29269',
                                                            country: 'MX',
                                                            phone_number: '8522847035'
                                                          })
                               })
      response = @gateway.verify(@credit_card, options)
      assert_success response
      assert_match %r{Accepted}, response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "failed verify for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      response = @gateway.verify(@declined_card, @options)
      assert_failure response
      assert_match %r{Invalid card or card type}, response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v1'],
  ].each do |integration_key, version|
    test "successful inquire for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))

      purchase = @gateway.purchase(@amount, @credit_card, @options)
      assert_success purchase

      inquire = @gateway.inquire(purchase.authorization)
      assert_success inquire

      assert_equal 'Accepted', purchase.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "invalid login for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      gateway = EbanxGateway.new(integration_key: '')

      response = gateway.purchase(@amount, @credit_card, @options)
      assert_failure response
      assert_match %r{Field integration_key is required}, response.message
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "transcript scrubbing for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      transcript = capture_transcript(@gateway) do
        @gateway.purchase(@amount, @credit_card, @options)
      end
      transcript = @gateway.scrub(transcript)

      assert_scrubbed(@credit_card.number, transcript)
      assert_scrubbed(@credit_card.verification_value, transcript)
    end
  end

  [
    [:ebanx, 'v1'],
    [:ebanx_v2, 'v2'],
  ].each do |integration_key, version|
    test "successful purchase with long order id for #{version}" do
      @gateway = EbanxGateway.new(fixtures(integration_key))
      options = @options.update(order_id: SecureRandom.hex(50))

      response = @gateway.purchase(@amount, @credit_card, options)
      assert_success response
      assert_equal 'Accepted', response.message
    end
  end
end
