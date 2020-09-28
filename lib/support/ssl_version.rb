require 'active_merchant'
require 'support/gateway_support'

class SSLVersion
  attr_accessor :success, :failed, :missing, :errored

  def initialize
    @gateways = GatewaySupport.new.gateways
    @success, @failed, @missing, @errored = [], [], [], []
  end

  def test_gateways(min_version = :TLS1_1)
    raise 'Requires Ruby 2.5 or better' unless Net::HTTP.instance_methods.include?(:min_version=)

    puts "Verifying #{@gateways.count} gateways for SSL min_version=#{min_version}\n\n"

    @gateways.each do |g|
      unless g.live_url
        missing << g unless g.abstract_class
        next
      end

      uri = URI.parse(g.live_url)
      result, message = test_min_version(uri, min_version)

      case result
      when :success
        print '.'
        success << g
      when :fail
        print 'F'
        failed << {gateway: g, message: message}
      when :error
        print 'E'
        errored << {gateway: g, message: message}
      end
    end

    print_summary
  end

  def print_summary
    puts "\n\nSucceeded gateways (#{success.length})"

    puts "\n\nFailed Gateways (#{failed.length}):"
    failed.each do |f|
      puts "#{f[:gateway].name} - #{f[:message]}"
    end

    puts "\n\nError Gateways (#{errored.length}):"
    errored.each do |e|
      puts "#{e[:gateway].name} - #{e[:message]}"
    end

    if missing.length > 0
      puts "\n\nGateways missing live_url (#{missing.length}):"
      missing.each do |m|
        puts m.name
      end
    end
  end

  private

  def test_min_version(uri, min_version)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # don't care about certificate validity, just protocol version
    http.min_version = min_version
    http.open_timeout = 10
    http.read_timeout = 10

    http.post('/', '')

    return :success
  rescue Net::HTTPBadResponse
    return :success # version negotiation succeeded
  rescue OpenSSL::SSL::SSLError => ex
    return :fail, ex.inspect
  rescue Interrupt => ex
    print_summary
    raise ex
  rescue StandardError => ex
    return :error, ex.inspect
  end
end
