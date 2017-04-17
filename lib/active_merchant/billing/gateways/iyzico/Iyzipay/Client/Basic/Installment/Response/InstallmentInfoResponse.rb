#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Installment
        module Response
          class InstallmentInfoResponse < Iyzipay::Client::Response
            attr_accessor :installment_details

            def from_json(json_result)
              Mapper::InstallmentInfoResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
