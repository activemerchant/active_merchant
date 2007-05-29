require 'rubygems'
require 'active_support'
require 'lib/active_merchant'


class GatewaySupport
  attr_reader :gateways
  
  def initialize
    @gateways = []
    ObjectSpace.each_object(Class) do |c|  
      if c.name =~ /Gateway/ && c.ancestors.reject{|a| a == c}.include?(ActiveMerchant::Billing::Gateway)
        gateways << c
      end
    end
    
    @gateways.delete(ActiveMerchant::Billing::BogusGateway)
    @gateways = @gateways.sort_by(&:name)
  end
  
  def each_gateway
    @gateways.each{|g| yield g }
  end
  
  def to_rdoc
    each_gateway do |g|
      puts "* {#{g.display_name}}[#{g.homepage_url}] - #{g.supported_countries.join(', ')}"
    end
  end
  
  def to_s
    each_gateway do |g|
      puts "#{g.display_name} - #{g.homepage_url} [#{g.supported_countries.join(', ')}]"
    end
  end
end


    