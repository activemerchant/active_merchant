require 'uri'
require 'net/http'
require 'net/http/digest_auth'

uri = URI.parse 'http://localhost:8000/'
uri.user = 'username'
uri.password = 'password'

h = Net::HTTP.new uri.host, uri.port
h.set_debug_output $stderr

req = Net::HTTP::Get.new uri.request_uri

res = h.request req

digest_auth = Net::HTTP::DigestAuth.new
auth = digest_auth.auth_header uri, res['www-authenticate'], 'GET'

req = Net::HTTP::Get.new uri.request_uri
req.add_field 'Authorization', auth

res = h.request req

puts
puts "passed" if res.code == '200'
puts "failed" if res.code != '200'

