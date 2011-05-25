# encoding: utf-8
require 'test_helper'

class ValitorReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @ret = Valitor::Return.new(http_raw_query)
  end

  def test_accessors
    assert @ret.complete?
    assert @ret.acknowledge
    assert @ret.success?
    assert_equal "OK", @ret.status
    assert_equal "2b969de3-6928-4fa7-a0d6-6dec63fec5c3", @ret.transaction_id
    assert_equal "order684afbb93730db2492a8fa2f3fedbcb9", @ret.order
    assert_equal "21.01.2011", @ret.received_at
    
    assert_equal "VISA", @ret.card_type
    assert_equal "9999", @ret.card_last_four
    assert_equal "123450", @ret.authorization_number
    assert_equal "F\303\206RSLUNR: 0026237", @ret.transaction_number
    assert_equal "NAME", @ret.customer_name
    assert_equal "123 ADDRESS", @ret.customer_address
    assert_equal "CITY", @ret.customer_city
    assert_equal "98765", @ret.customer_zip
    assert_equal "COUNTRY", @ret.customer_country
    assert_equal "EMAIL@EXAMPLE.COM", @ret.customer_email
    assert_equal "COMMENTS", @ret.customer_comment
    
    assert !@ret.test?
  end
  
  def test_acknowledge
    valid = Valitor::Return.new(http_raw_query, :credential2 => 'password')
    assert valid.acknowledge
    assert valid.success?
    assert valid.complete?
    
    invalid = Valitor::Return.new(http_raw_query, :credential2 => 'bogus')
    assert !invalid.acknowledge
    assert !invalid.success?
    assert !invalid.complete?
  end
  
  def test_test_mode
    assert Valitor::Return.new(http_raw_query, :test => true).test?
    assert !Valitor::Return.new(http_raw_query).test?
  end

  def http_raw_query
    "Kortategund=VISA&KortnumerSidustu=9999&Dagsetning=21.01.2011&Heimildarnumer=123450&Faerslunumer=FÆRSLUNR: 0026237&VefverslunSalaID=2b969de3-6928-4fa7-a0d6-6dec63fec5c3&Tilvisunarnumer=order684afbb93730db2492a8fa2f3fedbcb9&RafraenUndirskriftSvar=03d859813eff711d6c8667b0caf5f5a5&Upphaed=100&Nafn=NAME&Heimilisfang=123 ADDRESS&Postnumer=98765&Stadur=CITY&Land=COUNTRY&Tolvupostfang=EMAIL@EXAMPLE.COM&Athugasemdir=COMMENTS&LeyfirEndurtoku="
  end  
end