require 'net/http'

module NetHttpSslConnection
  module InnocuousCapitalize
    def capitalize(name) = name
    private :capitalize
  end

  class CaseSensitivePost < Net::HTTP::Post; prepend InnocuousCapitalize; end

  class CaseSensitivePatch < Net::HTTP::Patch; prepend InnocuousCapitalize; end

  class CaseSensitivePut < Net::HTTP::Put; prepend InnocuousCapitalize; end

  class CaseSensitiveDelete < Net::HTTP::Delete; prepend InnocuousCapitalize; end

  refine Net::HTTP do
    def ssl_connection
      return {} unless use_ssl? && @socket.present?

      { version: @socket.io.ssl_version, cipher: @socket.io.cipher[0] }
    end

    unless ENV['RUNNING_UNIT_TESTS']
      def post(path, data, initheader = nil, dest = nil, &block)
        send_entity(path, data, initheader, dest, request_type(CaseSensitivePost, Net::HTTP::Post, initheader), &block)
      end

      def patch(path, data, initheader = nil, dest = nil, &block)
        send_entity(path, data, initheader, dest, request_type(CaseSensitivePatch, Net::HTTP::Patch, initheader), &block)
      end

      def put(path, data, initheader = nil)
        request(request_type(CaseSensitivePut, Net::HTTP::Put, initheader).new(path, initheader), data)
      end

      def delete(path, initheader = { 'Depth' => 'Infinity' })
        request(request_type(CaseSensitiveDelete, Net::HTTP::Delete, initheader).new(path, initheader))
      end

      def request_type(replace, default, initheader)
        initheader.is_a?(ActiveMerchant::PostsData::CaseSensitiveHeaders) ? replace : default
      end
    end
  end
end
