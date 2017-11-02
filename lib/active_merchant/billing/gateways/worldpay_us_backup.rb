module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WorldpayUsBackupGateway < WorldpayUsGateway
      self.live_url = 'https://trans.gwtx01.com/cgi-bin/process.cgi'

      self.homepage_url = 'http://www.worldpay.com/us'
      self.display_name = 'WorldPay US (Backup)'
    end
  end
end
