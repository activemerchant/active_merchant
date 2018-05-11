require 'uri'
require 'set'

class OutboundHosts
  def self.list
    hosts = Set.new
    invalid_lines = Set.new

    Dir['lib/**/*.rb'].each do |file|
      content = File.read(file)

      content.each_line do |line|
        next if line =~ /homepage_url/

        if line =~ /("|')(https:\/\/[^'"]*)("|')/
          begin
            uri = URI.parse($2)
            hosts << "#{uri.host}:#{uri.port}"
          rescue URI::InvalidURIError
            invalid_lines << line
          end
        end
      end
    end

    [hosts, invalid_lines]
  end
end
