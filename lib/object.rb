class Object
  # obj.filter_bool_value -> true or false
  #
  # @return [Boolean]
  #
  # Returns this object if it is boolean true or false,
  # otherwise it yields the (optional) default
  def filter_boolean_value(default=false)
    return [true, false].include?(self) ? self : default
  end
end
