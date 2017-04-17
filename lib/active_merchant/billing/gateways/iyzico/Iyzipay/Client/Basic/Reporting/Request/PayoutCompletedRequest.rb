#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Reporting
        module Request
          class PayoutCompletedRequest < Iyzipay::Client::Request
            attr_accessor :date

            def get_json_object
              super.merge(
                  'date' => @date,
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:date, @date).
                  get_request_string
            end
          end
        end
      end
    end
  end
end

