require 'test_helper'
require 'nokogiri'

class PaypalExpressTest < Test::Unit::TestCase
  def setup
    @gateway = Class.new{ include PaypalCommonApi }

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }
  end

  def xml_builder
    Builder::XmlMarkup.new
  end

  def wrap_xml(&block)
    REXML::Document.new(@gateway.send(:build_request_wrapper, 'Action', &block))
  end

  def test_add_payment_details_adds_express_only_payment_details_when_necessary
    options = {:express_request => true}
    @gateway.expects(:add_express_only_payment_details)
    @gateway.send(:add_payment_details, xml_builder, 100, 'USD', options)
  end

  def test_add_payment_details_adds_items_details
    options = {:items => [1]}
    @gateway.expects(:add_payment_details_items_xml)
    @gateway.send(:add_payment_details, xml_builder, 100, 'USD', options)
  end

  def test_add_payment_details_adds_address
    options = {:shipping_address => @address}
    @gateway.expects(:add_address)
    @gateway.send(:add_payment_details, xml_builder, 100, 'USD', options)
  end

  def test_add_payment_details_adds_items_details_elements
    options = {:items => [{:name => 'foo'}]}
    request = wrap_xml do |xml|
      @gateway.send(:add_payment_details, xml, 100, 'USD', options)
    end
    assert_equal 'foo', REXML::XPath.first(request, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Name').text
  end

  def test_add_express_only_payment_details_adds_non_blank_fields
    request = wrap_xml do |xml|
      @gateway.send(:add_express_only_payment_details, xml, {:payment_action => 'Sale', :payment_request_id => ''})
    end
    assert_equal 'Sale', REXML::XPath.first(request, '//n2:PaymentAction').text
    assert_nil REXML::XPath.first(request, '//n2:PaymentRequestID')
  end
end
