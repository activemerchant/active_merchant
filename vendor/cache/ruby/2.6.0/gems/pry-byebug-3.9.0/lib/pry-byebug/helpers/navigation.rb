# frozen_string_literal: true

module PryByebug
  module Helpers
    #
    # Helpers to aid breaking out of the REPL loop
    #
    module Navigation
      #
      # Breaks out of the REPL loop and signals tracer
      #
      def breakout_navigation(action, options = {})
        pry_instance.binding_stack.clear

        throw :breakout_nav, action: action, options: options, pry: pry_instance
      end
    end
  end
end
