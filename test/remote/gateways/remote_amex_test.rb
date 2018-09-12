require 'test_helper'

class RemoteAmexTest < Test::Unit::TestCase
  def setup
    @gateway = AmexGateway.new(fixtures(:amex))

    @credit_card = ActiveMerchant::Billing::CreditCard.new(first_name: 'Bob',
                                                           last_name: 'Bobsen',
                                                           number: '345678901234564',
                                                           month: '5',
                                                           year: '21',
                                                           verification_value: '0000')

    @order_id       = SecureRandom.hex
    @transaction_id = SecureRandom.hex
  end

  def test_purchase_response_with_token
    response = @gateway.store(@credit_card)
    token = response.params['token']
    response = @gateway.purchase(12, token, order_id: @order_id, transaction_id: @transaction_id)
    assert response.success?
    assert_equal 12.0, response.params['order']['amount']
    assert_equal @order_id, response.params['order']['id']
    assert_equal 12.0, response.params['transaction']['amount']
    assert_equal @transaction_id, response.params['transaction']['id']
    assert_equal 'CAPTURE', response.params['transaction']['type']
    assert response.test?
  end

  def test_purchase_response_with_token_and_extra_order_options
    response = @gateway.store(@credit_card)
    token = response.params['token']
    response = @gateway.purchase(81.40, token, order_id: @order_id, transaction_id: @transaction_id, body: order)
    parsed_data = JSON.parse(order.to_json)
    order_one = parsed_data['order']['item'][0]
    order_two = parsed_data['order']['item'][1]
    response_order_item_one = response.params['order']['item'][0]
    response_order_item_two = response.params['order']['item'][1]
    assert response.success?
    assert_equal 81.40, response.params['order']['amount']
    assert_equal @order_id, response.params['order']['id']
    assert_equal 81.40, response.params['transaction']['amount']
    assert_equal @transaction_id, response.params['transaction']['id']
    assert_equal 'CAPTURE', response.params['transaction']['type']
    assert_equal order_one['unitTaxAmount'], response_order_item_one['unitTaxAmount'].to_s
    assert_equal order_one['quantity'], response_order_item_one['quantity']
    assert_equal order_one['unitPrice'], response_order_item_one['unitPrice'].to_s
    assert_equal order_one['description'], response_order_item_one['description'].to_s
    assert_equal order_one['name'], response_order_item_one['name']
    assert_equal order_two['unitTaxAmount'], response_order_item_two['unitTaxAmount'].to_s
    assert_equal order_two['quantity'], response_order_item_two['quantity']
    assert_equal order_two['unitPrice'], response_order_item_two['unitPrice'].to_s
    assert_equal order_two['description'], response_order_item_two['description'].to_s
    assert_equal order_two['name'], response_order_item_two['name']
    assert_equal parsed_data['order']['custom']['customerNumber'], response.params['order']['custom']['customerNumber']
    assert_equal parsed_data['order']['custom']['cardMemberNumber'], response.params['order']['custom']['cardMemberNumber']
    assert_equal parsed_data['order']['customerOrderDate'], response.params['order']['customerOrderDate']
    assert_equal parsed_data['order']['customerReference'], response.params['order']['customerReference']
    assert_equal parsed_data['order']['taxAmount'], response.params['order']['taxAmount'].to_s
    assert_equal parsed_data['shipping'], response.params['shipping']
    assert response.test?
  end

  def test_purchase_response_with_credit_card
    response = @gateway.purchase(12, @credit_card, order_id: @order_id, transaction_id: @transaction_id)
    assert response.success?
    assert_equal 12.0, response.params['order']['amount']
    assert_equal @order_id, response.params['order']['id']
    assert_equal 12.0, response.params['transaction']['amount']
    assert_equal @transaction_id, response.params['transaction']['id']
    assert_equal 'CAPTURE', response.params['transaction']['type']
    assert response.test?
  end

  def test_successful_refund_response
    refund_transaction_id = SecureRandom.hex
    response = @gateway.store(@credit_card)
    token = response.params['token']
    @gateway.purchase(12, token, order_id: @order_id, transaction_id: @transaction_id)
    response = @gateway.refund(12, order_id: @order_id, transaction_id: refund_transaction_id )
    assert response.success?
    assert_equal 12.0, response.params['order']['amount']
    assert_equal @order_id, response.params['order']['id']
    assert_equal 12.0, response.params['transaction']['amount']
    assert_equal refund_transaction_id, response.params['transaction']['id']
    assert_equal 'REFUND', response.params['transaction']['type']
    assert response.test?
  end

  def test_successful_refund_response_with_additonal_transaction_options
    transaction = {
      transaction: {
        item: [
          {
            unitTaxAmount: '0.5',
            quantity: 5,
            unitPrice: '5.0',
            description: 'Description Item 1',
            name: 'Item 1'
          },
          {
            unitTaxAmount: '0.7',
            quantity: 7,
            unitPrice: '7.0',
            description: 'Description Item 2',
            name: 'Item 2'
          }
        ],
        taxAmount: '7.4'
      }
    }
    refund_transaction_id = SecureRandom.hex
    response = @gateway.store(@credit_card)
    token = response.params['token']
    @gateway.purchase(81.40, token, order_id: @order_id, transaction_id: @transaction_id, body: order)
    response = @gateway.refund(81.40, order_id: @order_id, transaction_id: refund_transaction_id, body: transaction )
    parsed_data = JSON.parse(transaction.to_json)
    transaction_one = parsed_data['transaction']['item'][0]
    transaction_two = parsed_data['transaction']['item'][1]
    response_transaction_item_one = response.params['transaction']['item'][0]
    response_transaction_item_two = response.params['transaction']['item'][1]
    assert response.success?
    assert_equal 81.4, response.params['order']['amount']
    assert_equal @order_id, response.params['order']['id']
    assert_equal 81.4, response.params['transaction']['amount']
    assert_equal refund_transaction_id, response.params['transaction']['id']
    assert_equal 'REFUND', response.params['transaction']['type']
    assert_equal transaction_one['unitTaxAmount'], response_transaction_item_one['unitTaxAmount'].to_s
    assert_equal transaction_one['quantity'], response_transaction_item_one['quantity']
    assert_equal transaction_one['unitPrice'], response_transaction_item_one['unitPrice'].to_s
    assert_equal transaction_one['description'], response_transaction_item_one['description'].to_s
    assert_equal transaction_one['name'], response_transaction_item_one['name']
    assert_equal transaction_two['unitTaxAmount'], response_transaction_item_two['unitTaxAmount'].to_s
    assert_equal transaction_two['quantity'], response_transaction_item_two['quantity']
    assert_equal transaction_two['unitPrice'], response_transaction_item_two['unitPrice'].to_s
    assert_equal transaction_two['description'], response_transaction_item_two['description'].to_s
    assert_equal transaction_two['name'], response_transaction_item_two['name']
    assert_equal parsed_data['transaction']['taxAmount'], response.params['transaction']['taxAmount'].to_s
    assert response.test?
  end

  def test_successful_store_response
    response = @gateway.store(@credit_card)
    token = response.params['token']
    response = @gateway.store(@credit_card)
    assert response.success?
    assert_equal token, response.params['token']
    assert response.test?
  end

  def test_successful_update_card_response
    response = @gateway.store(@credit_card)
    token = response.params['token']
    response = @gateway.update_card(@credit_card)
    assert response.success?
    assert_equal token, response.params['token']
    assert response.test?
  end

  def test_successful_verify_response
    response = @gateway.store(@credit_card)
    token = response.params['token']
    response = @gateway.verify(token: token, order_id: @order_id, transaction_id: @transaction_id)
    assert response.success?
    assert_equal @order_id, response.params['order']['id']
    assert_equal @transaction_id, response.params['transaction']['id']
    assert response.test?
  end

  def test_successful_verify_response_with_extra_order_options
    verify_body_options = order
    verify_body_options[:order].delete(:customerOrderDate) && verify_body_options[:order].delete(:customerReference) 
    verify_body_options[:order][:amount] = '81.40'
    response = @gateway.store(@credit_card)
    token = response.params['token']
    response = @gateway.verify(token: token, order_id: @order_id, transaction_id: @transaction_id, body: verify_body_options)
    parsed_data = JSON.parse(order.to_json)
    order_one = parsed_data['order']['item'][0]
    order_two = parsed_data['order']['item'][1]
    response_order_item_one = response.params['order']['item'][0]
    response_order_item_two = response.params['order']['item'][1]
    assert response.success?
    assert_equal @order_id, response.params['order']['id']
    assert_equal @transaction_id, response.params['transaction']['id']
    assert_equal order_one['unitTaxAmount'], response_order_item_one['unitTaxAmount'].to_s
    assert_equal order_one['quantity'], response_order_item_one['quantity']
    assert_equal order_one['unitPrice'], response_order_item_one['unitPrice'].to_s
    assert_equal order_one['description'], response_order_item_one['description'].to_s
    assert_equal order_one['name'], response_order_item_one['name']
    assert_equal order_two['unitTaxAmount'], response_order_item_two['unitTaxAmount'].to_s
    assert_equal order_two['quantity'], response_order_item_two['quantity']
    assert_equal order_two['unitPrice'], response_order_item_two['unitPrice'].to_s
    assert_equal order_two['description'], response_order_item_two['description'].to_s
    assert_equal order_two['name'], response_order_item_two['name']
    assert_equal parsed_data['order']['custom']['customerNumber'], response.params['order']['custom']['customerNumber']
    assert_equal parsed_data['order']['custom']['cardMemberNumber'], response.params['order']['custom']['cardMemberNumber']
    assert_equal parsed_data['order']['taxAmount'], response.params['order']['taxAmount'].to_s
    assert_equal parsed_data['shipping'], response.params['shipping']
    assert response.test?
  end

  def test_successful_void_response
    response = @gateway.store(@credit_card)
    token = response.params['token']
    @gateway.purchase(12, token, order_id: @order_id, transaction_id: @transaction_id)
    void_transaction_id = SecureRandom.hex
    response = @gateway.void(@transaction_id, order_id: @order_id, transaction_id: void_transaction_id)
    assert response.success?
    assert response.test?
    assert_equal @order_id, response.params['order']['id']
    assert_equal void_transaction_id, response.params['transaction']['id']
    assert_equal @transaction_id, response.params['transaction']['targetTransactionId']
    assert_equal 'VOID_CAPTURE', response.params['transaction']['type']
  end

  def test_successful_void_response_with_custom_order_options
    order = {
      order: {
        custom: {
          customerOrderDate: '2018-07-15'
        }
      }
    }
    response = @gateway.store(@credit_card)
    token = response.params['token']
    @gateway.purchase(12, token, order_id: @order_id, transaction_id: @transaction_id)
    void_transaction_id = SecureRandom.hex
    response = @gateway.void(@transaction_id, order_id: @order_id, transaction_id: void_transaction_id, body: order)
    assert response.success?
    assert response.test?
    assert_equal @order_id, response.params['order']['id']
    assert_equal void_transaction_id, response.params['transaction']['id']
    assert_equal @transaction_id, response.params['transaction']['targetTransactionId']
    assert_equal 'VOID_CAPTURE', response.params['transaction']['type']
    assert_equal order[:order][:custom][:customerOrderDate], response.params['order']['custom']['customerOrderDate']
  end

  def test_delete_token_when_given_credit_card
    response = @gateway.delete_token(@credit_card)
    assert response.success?
    assert response.test?
  end

  def test_delete_token_when_given_token
    response = @gateway.store(@credit_card)
    token = response.params['token']
    response = @gateway.delete_token(token)
    assert response.success?
    assert response.test?
  end

  def test_find_transaction
    response = @gateway.store(@credit_card)
    token = response.params['token']
    @gateway.purchase(12, token, order_id: @order_id, transaction_id:  @transaction_id)
    response = @gateway.find_transaction(order_id: @order_id, transaction_id: @transaction_id)
    assert response.success?
    assert_equal @transaction_id, response.params['transaction']['id']
    assert response.test?
  end

  private
  def order
    {
      order: {
        custom: {
          customerNumber: '100',
          cardMemberNumber: '11223344'
        },
        customerOrderDate: '2018-07-15',
        customerReference: '7633721GMJ8A',
        item: [
          {
            unitTaxAmount: '0.5',
            quantity: 5,
            unitPrice: '5.0',
            description: 'Description Item 1',
            name: 'Item 1'
          },
          {
            unitTaxAmount: '0.7',
            quantity: 7,
            unitPrice: '7.0',
            description: 'Description Item 2',
            name: 'Item 2'
          }
        ],
          taxAmount: '7.4'
      },
      shipping: {
        address: {
          postcodeZip: '46237'
        }
      }
    }
  end
end
