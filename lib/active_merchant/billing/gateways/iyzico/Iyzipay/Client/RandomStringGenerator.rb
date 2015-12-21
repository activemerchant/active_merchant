#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    class RandomStringGenerator
      RANDOM_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

      def self.random_string(string_length)
        random_string = ''
        string_length.times do |idx|
          random_string << RANDOM_CHARS.split('').sample
        end
        random_string
      end
    end
  end
end
