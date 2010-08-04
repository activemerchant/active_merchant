require 'active_merchant/billing/buyer_auth_gateway'

Dir[File.dirname(__FILE__) + '/buyer_auth_gateways/*.rb'].each{ |g| require g }