%w(
  test_aliases
  test_associations
  test_attribute_methods
  test_attributes
  test_calculations
  test_callbacks
  test_composite_arrays
  test_counter_cache
  test_create
  test_delete
  test_dumpable
  test_dup
  test_enum
  test_equal
  test_exists
  test_find
  test_habtm
  test_ids
  test_miscellaneous
  test_nested_attributes
  test_optimistic
  test_pagination
  test_polymorphic
  test_predicates
  test_preload
  test_santiago
  test_serialize
  test_touch
  test_tutorial_example
  test_update
  test_validations
).each do |test|
  require File.expand_path("../#{test}", __FILE__)
end