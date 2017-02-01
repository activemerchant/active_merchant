require 'net/http'
require 'net/https'

module ActiveMerchant
  class DeleteWithBody < Net::HTTPRequest
    METHOD = 'DELETE'
    REQUEST_HAS_BODY = true
    RESPONSE_HAS_BODY = true
  end
end
