require 'net/http'

module NetHttpSslConnection
  refine Net::HTTP do
    def ssl_connection
      return {} unless use_ssl? && @socket.present?

      { version: @socket.io.ssl_version, cipher: @socket.io.cipher[0] }
    end
  end
end
