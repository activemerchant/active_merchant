##
# This class represents a select list where multiple values can be selected.
# MultiSelectList#value= accepts an array, and those values are used as
# values for the select list.  For example, to select multiple values,
# simply do this:
#
#   list.value = ['one', 'two']
#
# Single values are still supported, so these two are the same:
#
#   list.value = ['one']
#   list.value = 'one'

class Mechanize::Form::MultiSelectList < Mechanize::Form::Field
  extend Mechanize::ElementMatcher

  attr_accessor :options

  def initialize node
    value = []
    @options = node.search('option').map { |n|
      Mechanize::Form::Option.new(n, self)
    }

    super node, value
  end

  ##
  # :method: option_with
  #
  # Find one option on this select list with +criteria+
  #
  # Example:
  #
  #   select_list.option_with(:value => '1').value = 'foo'

  ##
  # :mehtod: option_with!(criteria)
  #
  # Same as +option_with+ but raises an ElementNotFoundError if no button
  # matches +criteria+

  ##
  # :method: options_with
  #
  # Find all options on this select list with +criteria+
  #
  # Example:
  #
  #   select_list.options_with(:value => /1|2/).each do |field|
  #     field.value = '20'
  #   end

  elements_with :option

  def query_value
    value ? value.map { |v| [name, v] } : ''
  end

  # Select no options
  def select_none
    @value = []
    options.each(&:untick)
  end

  # Select all options
  def select_all
    @value = []
    options.each(&:tick)
  end

  # Get a list of all selected options
  def selected_options
    @options.find_all(&:selected?)
  end

  def value=(values)
    select_none
    [values].flatten.each do |value|
      option = options.find { |o| o.value == value }
      if option.nil?
        @value.push(value)
      else
        option.select
      end
    end
  end

  def value
    @value + selected_options.map(&:value)
  end

end
