require 'test_helper'

class DirectebankingNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @deb = Directebanking.notification(http_raw_data, :credential4 => "3qx-:03DDfmUVh}b16#Y")
  end

  def test_accessors
    assert @deb.complete?
    assert_equal 'Completed', @deb.status
    assert_equal "19488-100576-4D6A7F5F-7FC4", @deb.transaction_id
    assert_equal "123456789", @deb.item_id
    assert_equal "1.00", @deb.gross
    assert_equal "EUR", @deb.currency
    assert_equal Time.parse("2011-02-27 17:45:23"), @deb.received_at
    assert @deb.test?
  end
  
  def test_compositions
    assert_equal Money.new(100, 'EUR'), @deb.amount
  end
    
  def test_acknowledgement    
    assert @deb.acknowledge
  end
  
  def test_acknowledgement_with_wrong_password
    @deb = Directebanking::Notification.new(http_raw_data, :credential4 => "XXXX")
    # needs to fail cause the password is wrong
    assert !@deb.acknowledge
  end
  
  def test_credential4_required
    assert_raises ArgumentError do
      Directebanking::Notification.new(http_raw_data, {})
    end
    assert_nothing_raised do
      Directebanking::Notification.new(http_raw_data, :credential4 => 'secret')
    end
  end
  
  def test_directebanking_attributes
    assert_equal "19488", @deb.user_id
    assert_equal "Project", @deb.reason_1
    assert_equal "Test", @deb.reason_2
    assert_equal "", @deb.user_variable_4
    assert_equal "", @deb.user_variable_5
  end
  
  def test_generate_signature_string
    assert_equal "19488-100576-4D6A7F5F-7FC4|19488|100576|Musterman, Petra|2345XXXXXX|00XXX|Testbank|PNAGXXXXXXX|AT680000XXXXXXXXXXXX|AT|BIZZONS eMarketing GmbH|0000XXXXXX|19XXX|Bankhaus KXXXXX|KREXXXXX|AT031952XXXXXXXXXXXX|AT|0|1.00|EUR|Project|Test|1|123456789|https://localhost:8080/directebanking/return|||||2011-02-27 17:45:23|3qx-:03DDfmUVh}b16#Y",
                 @deb.generate_signature_string
  end
  
  def test_generate_md5check
    assert_equal "9c39be1c7bfdb563467819f41d650fb4d2acad64", @deb.generate_signature
  end
  
  private
  def http_raw_data
    "transaction=19488-100576-4D6A7F5F-7FC4&user_id=19488&project_id=100576&sender_holder=Musterman%2C+Petra"+
    "&sender_account_number=2345XXXXXX&sender_bank_code=00XXX&sender_bank_name=Testbank&sender_bank_bic=PNAGXXXXXXX"+
    "&sender_iban=AT680000XXXXXXXXXXXX&sender_country_id=AT&recipient_holder=BIZZONS+eMarketing+GmbH"+
    "&recipient_account_number=0000XXXXXX&recipient_bank_code=19XXX&recipient_bank_name=Bankhaus+KXXXXX"+
    "&recipient_bank_bic=KREXXXXX&recipient_iban=AT031952XXXXXXXXXXXX&recipient_country_id=AT"+
    "&international_transaction=0&amount=1.00&currency_id=EUR&reason_1=Project&reason_2=Test&security_criteria=1"+
    "&user_variable_0=123456789&user_variable_1=https%3A%2F%2Flocalhost%3A8080%2Fdirectebanking%2Freturn&user_variable_2="+
    "&user_variable_3=&user_variable_4=&user_variable_5=&email_sender=&email_recipient="+
    "&created=2011-02-27+17%3A45%3A23&hash=9c39be1c7bfdb563467819f41d650fb4d2acad64"
  end  
end
