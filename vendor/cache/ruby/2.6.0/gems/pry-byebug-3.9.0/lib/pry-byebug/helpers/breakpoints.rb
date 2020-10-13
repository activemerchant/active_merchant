# frozen_string_literal: true

require "byebug"

module PryByebug
  module Helpers
    #
    # Common helpers for breakpoint related commands
    #
    module Breakpoints
      #
      # Byebug's array of breakpoints.
      #
      def breakpoints
        Pry::Byebug::Breakpoints
      end

      #
      # Prints a message with bold font.
      #
      def bold_puts(msg)
        output.puts(bold(msg))
      end

      #
      # Print out full information about a breakpoint.
      #
      # Includes surrounding code at that point.
      #
      def print_full_breakpoint(breakpoint)
        header = "Breakpoint #{breakpoint.id}:"
        status = breakpoint.enabled? ? "Enabled" : "Disabled"
        code = breakpoint.source_code.with_line_numbers.to_s
        condition = if breakpoint.expr
                      "#{bold('Condition:')} #{breakpoint.expr}\n"
                    else
                      ""
                    end

        output.puts <<-BREAKPOINT.gsub(/ {8}/, "")

          #{bold(header)} #{breakpoint} (#{status}) #{condition}

          #{code}

        BREAKPOINT
      end

      #
      # Print out concise information about a breakpoint.
      #
      def print_short_breakpoint(breakpoint)
        id = format("%*d", max_width, breakpoint.id)
        status = breakpoint.enabled? ? "Yes" : "No "
        expr = breakpoint.expr ? " #{breakpoint.expr} " : ""

        output.puts("  #{id} #{status}     #{breakpoint}#{expr}")
      end

      #
      # Prints a header for the breakpoint list.
      #
      def print_breakpoints_header
        header = "#{' ' * (max_width - 1)}# Enabled At "

        output.puts <<-BREAKPOINTS.gsub(/ {8}/, "")

          #{bold(header)}
          #{bold('-' * header.size)}

        BREAKPOINTS
      end

      #
      # Max width of breakpoints id column
      #
      def max_width
        breakpoints.last ? breakpoints.last.id.to_s.length : 1
      end
    end
  end
end
