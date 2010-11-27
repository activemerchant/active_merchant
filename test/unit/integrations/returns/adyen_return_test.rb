require 'test_helper'

class AdyenReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_successful_return
    r = Adyen::Return.new('merchantReference=1234&skinCode=fVmBwBe3&shopperLocale=en_GB&paymentMethod=visa&authResult=AUTHORISED&pspReference=8612537486987238&merchantSig=6T6mc7NDB1c5I6So816B2hYMNRY%3D',
                          :shared_secret => 'qceaihyyxiducsnczt6bdl7m5z4vao4f')
    assert r.success?
  end
  
  def test_failed_return
    r = Adyen::Return.new('merchantReference=1234&skinCode=fVmBwBe3&shopperLocale=en_GB&paymentMethod=visa&authResult=REFUSED&pspReference=8612537501807270&merchantSig=%2FPF97ddepNssgRHiWpCEfu1TnxI%3D',
                          :shared_secret => 'qceaihyyxiducsnczt6bdl7m5z4vao4f')
    assert_false r.success?
  end
  
  # important: this test ensures that if the digital signature is wrong, the transaction fails
  def test_bad_signature
    r = Adyen::Return.new('merchantReference=1234&skinCode=fVmBwBe3&shopperLocale=en_GB&paymentMethod=visa&authResult=AUTHORISED&pspReference=8612537486987238&merchantSig=6T6mc7NDB1c5I6So816B2hYMNRY%3D',
                          :shared_secret => 'QCEAIHYyxiducsnczt6bdl7m5z4vao4f') # NOTE this is intentionally the wrong shared secret, which should produce a signature verification failure
    assert_false r.success?
  end
  
end

