# frozen_string_literal: true

require "pry-byebug/helpers/navigation"

module PryByebug
  #
  # Display the current stack
  #
  class BacktraceCommand < Pry::ClassCommand
    include Helpers::Navigation

    match "backtrace"
    group "Byebug"

    description "Display the current stack."

    banner <<-BANNER
      Usage: backtrace

      Display the current stack.
    BANNER

    def process
      PryByebug.check_file_context(target)

      breakout_navigation :backtrace
    end
  end
end

Pry::Commands.add_command(PryByebug::BacktraceCommand)
