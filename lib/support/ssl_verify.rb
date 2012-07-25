require 'active_merchant'
require 'support/gateway_support'

class SSLVerify

  def initialize
    @gateways = GatewaySupport.new.gateways
  end

  def test_gateways
    success, failed, missing, errored = [], [], [], []

    puts GatewaySupport.new.gateways.map { |g| URI.parse(g.live_url).host if g.live_url }.compact.uniq.sort.join(', ')

    GatewaySupport.new.each_gateway do |g|
      if !g.live_url
        missing << g
        next
      end
      uri = URI.parse(g.live_url)
      puts uri.host + ', '
      result = ssl_verify_peer?(uri)
      case result
      when :success
        print "."
        success << g
      when :fail
        print "F"
        failed << g
      when :error
        print "E"
        errored << g
      end
    end

    puts "\n\n\nFailed Gateways:"
    failed.each do |f|
      puts f.name
    end

    puts "\n\nError Gateways:"
    errored.each do |e|
      puts e.name
    end
  end

  def try_host(http, path)
    http.get(path)
  rescue Net::HTTPBadResponse
    http.post(path, "")
  end

  def ssl_verify_peer?(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ca_file = File.dirname(__FILE__) + '/certs/cacert.pem'
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    if uri.path.blank?
      try_host(http, "/")
    else
      try_host(http, uri.path)
    end

    return :success
  rescue OpenSSL::SSL::SSLError
    return :fail
  rescue Net::HTTPBadResponse, Errno::ETIMEDOUT, EOFError, SocketError, Errno::ECONNREFUSED
    return :error
  end

end
