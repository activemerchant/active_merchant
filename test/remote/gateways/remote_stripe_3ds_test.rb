require 'test_helper'

class RemoteStripe3DSTest < Test::Unit::TestCase
  CHARGE_ID_REGEX = /ch_[a-zA-Z\d]{24}/

  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))
    @amount = 100

    @options = {
      :currency => 'USD',
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com',
      :execute_threed => true,
      :redirect_url => 'http://www.example.com/redirect',
      :callback_url => 'http://www.example.com/callback'
    }
    @credit_card = credit_card('4000000000003063')
    @non_3ds_card = credit_card('378282246310005')

    @stripe_account = fixtures(:stripe_destination)[:stripe_user_id]
  end

  def test_create_3ds_card_source
    assert response = @gateway.send(:create_source, @amount, @credit_card, 'card', @options)
    assert_success response
    assert_equal 'source', response.params['object']
    assert_equal 'chargeable', response.params['status']
    assert_equal 'required', response.params['card']['three_d_secure']
    assert_equal 'card', response.params['type']
  end

  def test_create_non3ds_card_source
    assert response = @gateway.send(:create_source, @amount, @non_3ds_card, 'card', @options)
    assert_success response
    assert_equal 'source', response.params['object']
    assert_equal 'chargeable', response.params['status']
    assert_equal 'not_supported', response.params['card']['three_d_secure']
    assert_equal 'card', response.params['type']
  end

  def test_create_3ds_source
    card_source  = @gateway.send(:create_source, @amount, @credit_card, 'card', @options)
    assert response = @gateway.send(:create_source, @amount, card_source.params['id'], 'three_d_secure',  @options)
    assert_success response
    assert_equal 'source', response.params['object']
    assert_equal 'pending', response.params['status']
    assert_equal 'three_d_secure', response.params['type']
    assert_equal false, response.params['three_d_secure']['authenticated']
  end

  def test_create_webhook_endpoint
    response = @gateway.send(:create_webhook_endpoint, @options, ['source.chargeable'])
    assert_includes response.params['enabled_events'], 'source.chargeable'
    assert_equal @options[:callback_url], response.params['url']
    assert_equal 'enabled', response.params['status']
    assert_nil response.params['application']

    deleted_response = @gateway.send(:delete_webhook_endpoint, @options.merge(:webhook_id => response.params['id']))
    assert_equal true, deleted_response.params['deleted']
  end

  def test_create_webhook_endpoint_on_connected_account
    response = @gateway.send(:create_webhook_endpoint, @options.merge({stripe_account: @stripe_account}), ['source.chargeable'])
    assert_includes response.params['enabled_events'], 'source.chargeable'
    assert_equal @options[:callback_url], response.params['url']
    assert_equal 'enabled', response.params['status']
    assert_not_nil response.params['application']

    deleted_response = @gateway.send(:delete_webhook_endpoint, @options.merge(:webhook_id => response.params['id']))
    assert_equal true, deleted_response.params['deleted']
  end

  def test_delete_webhook_endpoint
    webhook = @gateway.send(:create_webhook_endpoint, @options, ['source.chargeable'])
    response = @gateway.send(:delete_webhook_endpoint, @options.merge(:webhook_id => webhook.params['id']))
    assert_equal response.params['id'], webhook.params['id']
    assert_equal true, response.params['deleted']
  end

  def test_delete_webhook_endpoint_on_connected_account
    webhook = @gateway.send(:create_webhook_endpoint, @options.merge({stripe_account: @stripe_account}), ['source.chargeable'])
    response = @gateway.send(:delete_webhook_endpoint, @options.merge(:webhook_id => webhook.params['id']))
    assert_equal response.params['id'], webhook.params['id']
    assert_equal true, response.params['deleted']
  end

  def test_show_webhook_endpoint
    webhook = @gateway.send(:create_webhook_endpoint, @options, ['source.chargeable'])
    response = @gateway.send(:show_webhook_endpoint,  @options.merge(:webhook_id => webhook.params['id']))
    assert_includes response.params['enabled_events'], 'source.chargeable'
    assert_equal @options[:callback_url], response.params['url']
    assert_equal 'enabled', response.params['status']
    assert_nil response.params['application']

    deleted_response = @gateway.send(:delete_webhook_endpoint, @options.merge(:webhook_id => response.params['id']))
    assert_equal true, deleted_response.params['deleted']
  end

  def test_show_webhook_endpoint_on_connected_account
    webhook = @gateway.send(:create_webhook_endpoint, @options.merge({stripe_account: @stripe_account}), ['source.chargeable'])
    response = @gateway.send(:show_webhook_endpoint,  @options.merge({:webhook_id => webhook.params['id'], stripe_account: @stripe_account}))

    assert_includes response.params['enabled_events'], 'source.chargeable'
    assert_equal @options[:callback_url], response.params['url']
    assert_equal 'enabled', response.params['status']
    assert_not_nil response.params['application']

    deleted_response = @gateway.send(:delete_webhook_endpoint, @options.merge(:webhook_id => response.params['id']))
    assert_equal true, deleted_response.params['deleted']
  end

  def test_list_webhook_endpoints
    webhook1 = @gateway.send(:create_webhook_endpoint, @options, ['source.chargeable'])
    webhook2 = @gateway.send(:create_webhook_endpoint, @options.merge({stripe_account: @stripe_account}), ['source.chargeable'])
    assert_nil webhook1.params['application']
    assert_not_nil webhook2.params['application']

    response = @gateway.send(:list_webhook_endpoints,  @options.merge({limit: 100}))
    assert_not_nil response.params
    assert_equal 'list', response.params['object']
    assert response.params['data'].size >= 2
    webhook_id_set = Set.new(response.params['data'].map { |webhook| webhook['id'] }.uniq)
    assert Set[webhook1.params['id'], webhook2.params['id']].subset?(webhook_id_set)

    deleted_response1 = @gateway.send(:delete_webhook_endpoint, @options.merge(:webhook_id => webhook1.params['id']))
    deleted_response2 = @gateway.send(:delete_webhook_endpoint, @options.merge(:webhook_id => webhook2.params['id']))
    assert_equal true, deleted_response1.params['deleted']
    assert_equal true, deleted_response2.params['deleted']
  end

end
