#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Bin
        module Request
          class BinCheckRequest < Iyzipay::Client::Request
            attr_accessor :binNumber

            def get_json_object
              super.merge(
                  'binNumber' => @binNumber
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:binNumber, @binNumber).
                  get_request_string
            end
          end
        end
      end
    end
  end
end


