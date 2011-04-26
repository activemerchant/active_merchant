require 'uri'
require 'set'

class OutboundHosts
  def self.list    
    uris = Set.new

    Dir['lib/**/*.rb'].each do |file|
      content = File.read(file)

      content.each_line do |line|
        next if line =~ /homepage_url/
    
        if line =~ /("|')(https:\/\/.*)("|')/
          uri = URI.parse($2)
          uris << [uri.host, uri.port]
        end
      end
    end

    uris.each do |uri|
      puts "#{uri.first} #{uri.last}"
    end
  end
end