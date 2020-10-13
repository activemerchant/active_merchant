require 'timeout'
require 'socket'

TCPSocket.class_eval do
  def self.wait_for_service(options)
    Timeout::timeout(options[:timeout] || 20) do
      loop do
        begin
          socket = TCPSocket.new(options[:host], options[:port])
          socket.close
          return
        rescue Errno::ECONNREFUSED
          sleep 0.5
        end
      end
    end
  end
end
