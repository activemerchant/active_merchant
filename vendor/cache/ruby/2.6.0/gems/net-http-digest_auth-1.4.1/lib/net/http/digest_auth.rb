require 'cgi'
require 'digest'
require 'monitor'
require 'net/http'
require 'securerandom'

##
# An implementation of RFC 2617 Digest Access Authentication.
#
# http://www.rfc-editor.org/rfc/rfc2617.txt
#
# Here is a sample usage of DigestAuth on Net::HTTP:
#
#   require 'uri'
#   require 'net/http'
#   require 'net/http/digest_auth'
#
#   digest_auth = Net::HTTP::DigestAuth.new
#
#   uri = URI.parse 'http://localhost:8000/'
#   uri.user = 'username'
#   uri.password = 'password'
#
#   h = Net::HTTP.new uri.host, uri.port
#
#   req = Net::HTTP::Get.new uri.request_uri
#
#   res = h.request req
#   # res is a 401 response with a WWW-Authenticate header
#
#   auth = digest_auth.auth_header uri, res['www-authenticate'], 'GET'
#
#   # create a new request with the Authorization header
#   req = Net::HTTP::Get.new uri.request_uri
#   req.add_field 'Authorization', auth
#
#   # re-issue request with Authorization
#   res = h.request req

class Net::HTTP::DigestAuth

  include MonitorMixin

  ##
  # DigestAuth error class

  class Error < RuntimeError; end

  ##
  # Version of Net::HTTP::DigestAuth you are using

  VERSION = '1.4.1'

  ##
  # Creates a new DigestAuth header creator.

  def initialize ignored = :ignored
    mon_initialize
    @nonce_count = -1
  end

  ##
  # Creates a digest auth header for +uri+ from the +www_authenticate+ header
  # for HTTP method +method+.
  #
  # The result of this method should be sent along with the HTTP request as
  # the "Authorization" header.  In Net::HTTP this will look like:
  #
  #   request.add_field 'Authorization', digest_auth.auth_header # ...
  #
  # See Net::HTTP::DigestAuth for a complete example.
  #
  # IIS servers handle the "qop" parameter of digest authentication
  # differently so you may need to set +iis+ to true for such servers.

  def auth_header uri, www_authenticate, method, iis = false
    nonce_count = next_nonce

    user     = CGI.unescape uri.user
    password = CGI.unescape uri.password

    www_authenticate =~ /^(\w+) (.*)/

    challenge = $2

    params = {}
    challenge.gsub(/(\w+)="(.*?)"/) { params[$1] = $2 }

    challenge =~ /algorithm="?(.*?)"?([, ]|$)/

    params['algorithm'] = $1 || 'MD5'

    if params['algorithm'] =~ /(.*?)(-sess)?$/
      algorithm = case $1
                  when 'MD5'    then Digest::MD5
                  when 'SHA1'   then Digest::SHA1
                  when 'SHA2'   then Digest::SHA2
                  when 'SHA256' then Digest::SHA256
                  when 'SHA384' then Digest::SHA384
                  when 'SHA512' then Digest::SHA512
                  when 'RMD160' then Digest::RMD160
                  else raise Error, "unknown algorithm \"#{$1}\""
                  end
      sess = $2
    end

    qop = params['qop']
    cnonce = make_cnonce if qop or sess

    a1 = if sess then
           [ algorithm.hexdigest("#{user}:#{params['realm']}:#{password}"),
             params['nonce'],
             cnonce,
           ].join ':'
         else
           "#{user}:#{params['realm']}:#{password}"
         end

    ha1 = algorithm.hexdigest a1
    ha2 = algorithm.hexdigest "#{method}:#{uri.request_uri}"

    request_digest = [ha1, params['nonce']]
    request_digest.push(('%08x' % nonce_count), cnonce, qop) if qop
    request_digest << ha2
    request_digest = request_digest.join ':'

    header = [
      "Digest username=\"#{user}\"",
      "realm=\"#{params['realm']}\"",
      "algorithm=#{params['algorithm']}",
      if qop.nil? then
      elsif iis then
        "qop=\"#{qop}\""
      else
        "qop=#{qop}"
      end,
      "uri=\"#{uri.request_uri}\"",
      "nonce=\"#{params['nonce']}\"",
      if qop then
        [
          "nc=#{'%08x' % @nonce_count}",
          "cnonce=\"#{cnonce}\"",
        ]
      end,
      "response=\"#{algorithm.hexdigest(request_digest)}\"",
      if params.key? 'opaque' then
        "opaque=\"#{params['opaque']}\""
      end
    ].compact

    header.join ', '
  end

  ##
  # Creates a client nonce value that is used across all requests based on the
  # current time, process id and a random number

  def make_cnonce
    Digest::MD5.hexdigest [
      Time.now.to_i,
      $$,
      SecureRandom.random_number(2**32),
    ].join ':'
  end

  def next_nonce
    synchronize do
      @nonce_count += 1
    end
  end

end

