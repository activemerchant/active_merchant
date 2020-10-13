module Mocha
  class Cardinality
    INFINITY = 1 / 0.0

    class << self
      def exactly(count)
        new(count, count)
      end

      def at_least(count)
        new(count, INFINITY)
      end

      def at_most(count)
        new(0, count)
      end

      def times(range_or_count)
        case range_or_count
        when Range then new(range_or_count.first, range_or_count.last)
        else new(range_or_count, range_or_count)
        end
      end
    end

    def initialize(required, maximum)
      @required = required
      @maximum = maximum
      @invocations = []
    end

    def <<(invocation)
      @invocations << invocation
    end

    def invocations_allowed?
      @invocations.size < maximum
    end

    def satisfied?
      @invocations.size >= required
    end

    def needs_verifying?
      !allowed_any_number_of_times?
    end

    def verified?
      (@invocations.size >= required) && (@invocations.size <= maximum)
    end

    def allowed_any_number_of_times?
      required.zero? && infinite?(maximum)
    end

    def used?
      @invocations.any? || maximum.zero?
    end

    # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    def anticipated_times
      if allowed_any_number_of_times?
        'allowed any number of times'
      elsif required.zero? && maximum.zero?
        "expected #{times(maximum)}"
      elsif required == maximum
        "expected exactly #{times(required)}"
      elsif infinite?(maximum)
        "expected at least #{times(required)}"
      elsif required.zero?
        "expected at most #{times(maximum)}"
      else
        "expected between #{required} and #{times(maximum)}"
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

    def invoked_times
      "invoked #{times(@invocations.size)}"
    end

    def actual_invocations
      @invocations.map(&:full_description).join
    end

    protected

    attr_reader :required, :maximum

    def times(number)
      case number
      when 0 then 'never'
      when 1 then 'once'
      when 2 then 'twice'
      else "#{number} times"
      end
    end

    def infinite?(number)
      number.respond_to?(:infinite?) && number.infinite?
    end
  end
end
