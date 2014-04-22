# encoding: utf-8
require 'test_helper'

class PagSeguroNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @uri = stub(:query=)
    URI.expects(:join).with(PagSeguro.notification_url, notification_code).returns(@uri)
  end

  def test_accessors
    Net::HTTP.expects(:get_response).with(@uri).returns(stub(body: http_raw_data))
    pag_seguro = PagSeguro::Notification.new(notification_data)

    assert pag_seguro.complete?
    assert_equal "Completed", pag_seguro.status
    assert_equal "9E884542-81B3-4419-9A75-BCC6FB495EF1", pag_seguro.transaction_id
    assert_equal "REF1234", pag_seguro.item_id
    assert_equal "49.12", pag_seguro.gross
    assert_equal "BRL", pag_seguro.currency
    assert_equal "1", pag_seguro.payment_method_type
    assert_equal "101", pag_seguro.payment_method_code
    assert_equal "2011-02-10T16:13:41.000-03:00", pag_seguro.received_at
  end

  def test_compositions
    Net::HTTP.expects(:get_response).with(@uri).returns(stub(body: http_raw_data))
    pag_seguro = PagSeguro::Notification.new(notification_data)
    assert_equal Money.new(4912, 'BRL'), pag_seguro.amount
  end

  def test_respond_to_acknowledge
    Net::HTTP.expects(:get_response).with(@uri).returns(stub(body: http_raw_data))
    pag_seguro = PagSeguro::Notification.new(notification_data)
    assert pag_seguro.respond_to?(:acknowledge)
  end

  def test_pending_state_when_status_1
    Net::HTTP.expects(:get_response).with(@uri).returns(stub(body: http_raw_data_status_only(1)))
    pag_seguro = PagSeguro::Notification.new(notification_data)

    refute pag_seguro.complete?
    assert_equal "Pending", pag_seguro.status
  end

  def test_pending_state_when_status_2
    Net::HTTP.expects(:get_response).with(@uri).returns(stub(body: http_raw_data_status_only(2)))
    pag_seguro = PagSeguro::Notification.new(notification_data)

    refute pag_seguro.complete?
    assert_equal "Pending", pag_seguro.status
  end

  private
  def notification_code
    "766B9C-AD4B044B04DA-77742F5FA653-E1AB24"
  end
  def notification_data
    "notificationCode=#{notification_code}&notificationType=transaction"
  end

  def http_raw_data_status_only(status)
    <<-DATA
      <?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?>
      <transaction>
          <code>9E884542-81B3-4419-9A75-BCC6FB495EF1</code>
          <type>1</type>
          <status>#{status}</status>
      </transaction>
    DATA
  end

  def http_raw_data
    <<-DATA
      <?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?>
      <transaction>
          <date>2011-02-10T16:13:41.000-03:00</date>
          <code>9E884542-81B3-4419-9A75-BCC6FB495EF1</code>
          <reference>REF1234</reference>
          <type>1</type>
          <status>3</status>
          <lastEventDate>2011-02-15T17:39:14.000-03:00</lastEventDate>
          <paymentMethod>
              <type>1</type>
              <code>101</code>
          </paymentMethod>
          <grossAmount>49.12</grossAmount>
          <discountAmount>0.00</discountAmount>
          <feeAmount>0.00</feeAmount>
          <netAmount>49900.00</netAmount>
          <extraAmount>0.00</extraAmount>
          <installmentCount>1</installmentCount>
          <itemCount>2</itemCount>
          <items>
              <item>
                  <id>0001</id>
                  <description>Notebook Prata</description>
                  <quantity>1</quantity>
                  <amount>24300.00</amount>
              </item>
          </items>
          <sender>
              <name>José Comprador</name>
              <email>comprador@uol.com.br</email>
              <phone>
                  <areaCode>11</areaCode>
                  <number>56273440</number>
              </phone>
          </sender>
          <shipping>
              <address>
                  <street>Av. Brig. Faria Lima</street>
                  <number>1384</number>
                  <complement>5o andar</complement>
                  <district>Jardim Paulistano</district>
                  <postalCode>01452002</postalCode>
                  <city>Sao Paulo</city>
                  <state>SP</state>
                  <country>BRA</country>
              </address>
              <type>1</type>
              <cost>21.50</cost>
          </shipping>
      </transaction>
    DATA
  end
end
