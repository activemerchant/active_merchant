#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    class HttpClientTemplate
      def self.get(url, header)
        RestClient.get(url, header)
      end

      def self.post(url, header, content)
        RestClient.post(url, content, header)
      end

      def self.put(url, header, content)
        RestClient.put(url, content, header)
      end

      def self.delete(url, headers={},content,&block)
        RestClient::Request.execute(:method => :delete, :url => url, :payload => content, :headers => headers, &block)
      end

    end
  end
end
