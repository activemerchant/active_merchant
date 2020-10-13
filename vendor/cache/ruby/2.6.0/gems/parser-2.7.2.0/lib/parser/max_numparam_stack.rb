# frozen_string_literal: true

module Parser

  class MaxNumparamStack
    attr_reader :stack

    def initialize
      @stack = []
    end

    def has_ordinary_params!
      set(-1)
    end

    def has_ordinary_params?
      top < 0
    end

    def has_numparams?
      top && top > 0
    end

    def register(numparam)
      set( [top, numparam].max )
    end

    def top
      @stack.last
    end

    def push
      @stack.push(0)
    end

    def pop
      @stack.pop
    end

    private

    def set(value)
      @stack.pop
      @stack.push(value)
    end
  end

end
