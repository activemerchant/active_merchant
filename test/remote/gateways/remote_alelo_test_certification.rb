require 'test_helper'
require 'singleton'

class RemoteAleloTestCertification < Test::Unit::TestCase
  def setup
    @gateway = AleloGateway.new(fixtures(:alelo_certification))
    @amount = 1000
    @cc_alimentacion = credit_card('5098870005467012', {
      month: 8,
      year: 2027,
      first_name: 'Longbob',
      last_name: 'Longsen',
      verification_value: 747,
      brand: 'mc'
    })
    @cc_snack = credit_card('5067580024660011', {
      month: 8,
      year: 2027,
      first_name: 'Longbob',
      last_name: 'Longsen',
      verification_value: 576,
      brand: 'mc'
    })
    @options = {
      order_id: SecureRandom.uuid,
      establishment_code: '1040471819',
      sub_merchant_mcc: '5499',
      player_identification: '7',
      description: 'Store Purchase',
      external_trace_number: '123456'
    }
  end

  def test_failure_purchase_with_wrong_cvv_ct05
    set_credentials!
    @cc_snack.verification_value = 999
    response = @gateway.purchase(@amount, @cc_snack, @options)

    assert_failure response
    assert_match %r{incorreto}i, response.message
  end

  def test_failure_with_incomplete_required_options_ct06
    set_credentials!
    @options.delete(:establishment_code)
    response = @gateway.purchase(@amount, @cc_alimentacion, @options)

    assert_failure response
    assert_match %r{Erro ao validar dados}i, response.message
  end

  def test_failure_refund_with_non_existent_uuid_ct07
    set_credentials!
    response = @gateway.refund(@amount, SecureRandom.uuid, {})

    assert_failure response
    assert_match %r{RequestId informado, não encontrado!}, response.message
  end

  def test_successful_purchase_with_alimentazao_cc_ct08
    response = @gateway.purchase(@amount, @cc_alimentacion, @options)

    assert_success response
    assert_match %r{confirmada}i, response.message
  end

  # Testing High value transaction disables the test credit card
  #
  # def test_successful_purchase_with_alimentazao_cc_ct08_B_high_value
  #   response = @gateway.purchase(10_000_000, @cc_alimentacion, @options)
  #   assert_failure response
  # end

  def test_successful_refund_ct09
    set_credentials!
    purchase = @gateway.purchase(@amount, @cc_alimentacion, @options)
    response = @gateway.refund(@amount, purchase.authorization, {})

    assert_success response
    assert_match %r{Transação Estornada com sucesso}, response.message
  end

  def test_failure_with_non_exitent_establishment_code_ct10
    @options[:establishment_code] = '0987654321'
    @options[:sub_merchant_mcc] = '5411'

    response = @gateway.purchase(@amount, @cc_alimentacion, @options)

    assert_failure response
    assert_match %r{no adquirente}i, response.message
  end

  def test_failure_when_cc_expired_ct11
    @cc_alimentacion.year = 2020
    set_credentials!

    response = @gateway.purchase(@amount, @cc_alimentacion, @options)

    assert_failure response
  end

  def test_failure_refund_with_purchase_already_refunded_ct12
    set_credentials!
    purchase = @gateway.purchase(@amount, @cc_alimentacion, @options)
    assert_success purchase

    response = @gateway.refund(@amount, purchase.authorization, {})
    assert_success response

    response = @gateway.refund(@amount, purchase.authorization, {})
    assert_failure response
  end

  private

  def set_credentials!
    if AleloCredentials.instance.access_token.nil?
      credentials = @gateway.send :ensure_credentials, {}
      AleloCredentials.instance.access_token = credentials[:access_token]
      AleloCredentials.instance.key = credentials[:key]
      AleloCredentials.instance.uuid = credentials[:uuid]
    end

    @gateway.options[:access_token] = AleloCredentials.instance.access_token
    @gateway.options[:encryption_key] = AleloCredentials.instance.key
    @gateway.options[:encryption_uuid] = AleloCredentials.instance.uuid
  end
end

# A simple singleton so an access token and key can
# be shared among several tests
class AleloCredentials
  include Singleton

  attr_accessor :access_token, :key, :uuid
end
