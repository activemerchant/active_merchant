##
# This class represents a radio button found in a Form.  To activate the
# RadioButton in the Form, set the checked method to true.

class Mechanize::Form::RadioButton < Mechanize::Form::Field
  attr_accessor :checked
  attr_reader :form

  def initialize node, form
    @checked = !!node['checked']
    @form    = form
    super(node)
  end

  def == other # :nodoc:
    self.class === other and
      other.form  == @form and
      other.name  == @name and
      other.value == @value
  end

  alias eql? == # :nodoc:

  def check
    uncheck_peers
    @checked = true
  end

  alias checked? checked

  def uncheck
    @checked = false
  end

  def click
    checked ? uncheck : check
  end

  def hash # :nodoc:
    @form.hash ^ @name.hash ^ @value.hash
  end

  def label
    (id = self['id']) && @form.page.labels_hash[id] || nil
  end

  def text
    label.text rescue nil
  end

  def [](key)
    @node[key]
  end

  def pretty_print_instance_variables # :nodoc:
    [:@checked, :@name, :@value]
  end

  private

  def uncheck_peers
    @form.radiobuttons_with(:name => name).each do |b|
      next if b.value == value
      b.uncheck
    end
  end

end

