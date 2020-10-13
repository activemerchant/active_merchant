# This class represents a select list or drop down box in a Form.  Set the
# value for the list by calling SelectList#value=.  SelectList contains a list
# of Option that were found.  After finding the correct option, set the select
# lists value to the option value:
#
#   selectlist.value = selectlist.options.first.value
#
# Options can also be selected by "clicking" or selecting them.  See Option
class Mechanize::Form::SelectList < Mechanize::Form::MultiSelectList

  def initialize node
    super
    if selected_options.length > 1
      selected_options.reverse[1..selected_options.length].each do |o|
        o.unselect
      end
    end
  end

  def value
    value = super
    if value.length > 0
      value.last
    elsif @options.length > 0
      @options.first.value
    else
      nil
    end
  end

  def value=(new_value)
    if new_value != new_value.to_s and new_value.respond_to? :first
      super([new_value.first])
    else
      super([new_value.to_s])
    end
  end

  def query_value
    value ? [[name, value]] : nil
  end

end

