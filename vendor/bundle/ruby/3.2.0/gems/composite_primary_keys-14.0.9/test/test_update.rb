require File.expand_path('../abstract_unit', __FILE__)

class TestUpdate < ActiveSupport::TestCase
  fixtures :departments, :reference_types, :reference_codes, :rooms, :room_assignments

  CLASSES = {
    :single => {
      :class => ReferenceType,
      :primary_keys => :reference_type_id,
      :update => { :description => 'RT Desc' },
    },
    :dual   => {
      :class => ReferenceCode,
      :primary_keys => [:reference_type_id, :reference_code],
      :update => { :description => 'RT Desc' },
    },
  }

  def setup
    self.class.classes = CLASSES
  end

  def test_setup
    testing_with do
      assert_not_nil @klass_info[:update]
    end
  end

  def test_update_attributes
    testing_with do
      assert(@first.update(@klass_info[:update]))
      assert(@first.reload)
      @klass_info[:update].each_pair do |attr_name, new_value|
        assert_equal(new_value, @first[attr_name])
      end
    end
  end

  def test_update_attributes_with_id_field
    department = departments(:accounting)
    department.update_attribute(:location_id, 3)
    department.reload
    assert_equal(3, department.location_id)
  end

  def test_update_primary_key
    obj = ReferenceCode.find([1,1])
    obj.reference_type_id = 2
    obj.reference_code = 3
    assert_equal({"reference_type_id" => 2, "reference_code" => 3}, obj.ids_hash)
    assert(obj.save)
    assert(obj.reload)
    assert_equal(2, obj.reference_type_id)
    assert_equal(3, obj.reference_code)
    assert_equal({"reference_type_id" => 2, "reference_code" => 3}, obj.ids_hash)
    assert_equal([2, 3], obj.id)
  end

  def test_update_attribute
    obj = ReferenceType.find(1)
    obj[:abbreviation] = 'a'
    obj['abbreviation'] = 'b'
    assert(obj.save)
    assert(obj.reload)
    assert_equal('b', obj.abbreviation)
  end

  def test_update_all
    ReferenceCode.update_all(description: 'random value')

    ReferenceCode.all.each do |reference_code|
      assert_equal('random value', reference_code.description)
    end
  end

  def test_update_all_join
    tested_update_all = false
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
    ReferenceCode.joins(:reference_type).
                  where('reference_types.reference_type_id = ?', 2).
                  update_all(:description => 'random value')

    query = ReferenceCode.where('reference_type_id = ?', 2).
                          where(:description => 'random value')

    assert_equal(2, query.count)
    tested_update_all = true
  ensure
    Arel::Table.engine = ActiveRecord::Base
    assert tested_update_all
  end

  def test_update_with_uniqueness
    assignment = room_assignments(:jacksons_room)
    room_1 = rooms(:branner_room_1)
    room_2 = rooms(:branner_room_3)

    assert_equal(room_1, assignment.room)
    assignment.room = room_2
    assignment.save!
    assert_equal(room_2, assignment.room)
  end
end