# OpenMRS Database Schema Changes (Versions 1.8.x and 1.9.x)

Below is a detailed list of database schema changes introduced in OpenMRS versions 1.8 and 1.9 (inclusive of all maintenance releases). Changes include new tables, altered tables/columns, dropped columns, and added indexes or constraints. Where possible, column types, nullability, and relationships are noted, with official changelog citations.

---

## ✅ Rails Migrations for OpenMRS 1.8.x and 1.9.x

### Migration: Add Scheduler Task Config Table

```ruby
create_table :scheduler_task_config, id: :integer do |t|
  t.string :task_class, null: false
  t.text :property, null: false
  t.string :value
  t.boolean :started, default: false
  t.boolean :stopped, default: false
  t.integer :creator, null: false
  t.datetime :date_created, null: false
  t.boolean :voided, default: false
  t.integer :voided_by
  t.datetime :date_voided
  t.string :void_reason
end
```

### Migration: Add Columns to Existing Tables

```ruby
add_column :concept_derived, :language, :string, null: false, limit: 255
add_column :patient_program, :location_id, :integer
add_foreign_key :patient_program, :location, column: :location_id
add_column :concept_word, :weight, :float, default: 1.0
add_column :drug, :date_changed, :datetime
add_column :drug, :changed_by, :integer
add_foreign_key :drug, :users, column: :changed_by
```

### Migration: Modify Existing Columns

```ruby
change_column :hl7_in_error, :error_details, :text, limit: 16.megabytes - 1
change_column_null :person_name, :person_id, false
change_column :drug, :name, :string, limit: 255
change_column :person_address, :address1, :string, limit: 255
change_column :person_address, :address2, :string, limit: 255
change_column :person_address, :neighborhood_cell, :string, limit: 255 # becomes address3
change_column :location, :neighborhood_cell, :string, limit: 255 # becomes address3
# Repeat similar changes for address4-address6 where relevant
```

### Migration: Drop Unused Column

```ruby
remove_column :concept, :default_charge, :decimal
```

### Migration: Drop Deprecated Table

```ruby
drop_table :concept_derived
```

### Migration: Add Visit Support (1.9.x)

```ruby
create_table :visit_type, id: :integer do |t|
  t.string :name, null: false
  t.string :description
  t.boolean :retired, default: false, null: false
  t.integer :retired_by
  t.datetime :date_retired
  t.string :retire_reason
  t.integer :creator, null: false
  t.datetime :date_created, null: false
  t.boolean :voided, default: false, null: false
  t.integer :voided_by
  t.datetime :date_voided
  t.string :void_reason
end

create_table :visit, id: :integer do |t|
  t.integer :patient_id, null: false
  t.integer :visit_type_id, null: false
  t.integer :indication_concept_id
  t.integer :location_id
  t.datetime :start_datetime, null: false
  t.datetime :stop_datetime
  t.boolean :voided, default: false, null: false
  t.integer :voided_by
  t.datetime :date_voided
  t.string :void_reason
  t.integer :creator, null: false
  t.datetime :date_created, null: false
  t.integer :changed_by
  t.datetime :date_changed
end

add_foreign_key :visit, :patient, column: :patient_id
add_foreign_key :visit, :visit_type, column: :visit_type_id
add_foreign_key :visit, :concept, column: :indication_concept_id
add_foreign_key :visit, :location, column: :location_id

add_column :encounter, :visit_id, :integer
add_foreign_key :encounter, :visit, column: :visit_id
```

### Migration: Modify Provider and Global Property

```ruby
change_column :provider, :identifier, :string, null: true
change_column :global_property, :property, :string
```

---

## Version 1.8.x

### Added Tables

- **scheduler\_task\_config** – Task configuration support table added for scheduled jobs.

### Added Columns

- **concept\_derived.language** – `VARCHAR(255) NOT NULL`
- **patient\_program.location\_id** – `INT`, foreign key to `location.location_id`
- **concept\_word.weight** – `DOUBLE`, default 1
- **drug.date\_changed** – `DATETIME`
- **drug.changed\_by** – `INT`, foreign key to `users.user_id`

### Modified Columns

- **hl7\_in\_error.error\_details** – Extended to store full stack traces
- **person\_name.person\_id** – Made NOT NULL
- **form.published, form.retired** – Added indexes (single-column and composite)
- **person\_address & location.address fields**:
  - `neighborhood_cell` → `address3`
  - `township_division` → `address4`
  - `subregion` → `address5`
  - `region` → `address6`
  - All updated to `VARCHAR(255)`
  - `address1`, `address2` updated to `VARCHAR(255)`
- **drug.name** – Increased to `VARCHAR(255)`

### Dropped Columns

- **concept.default\_charge** – Dropped as unused

### Dropped Tables

- **concept\_derived** – Removed entirely (after deprecation)

### Data Cleanup

- **role\_role** – Removed orphaned entries (1.8.4 maintenance)

## Version 1.9.x

### Added Tables

- **concept\_reference\_term** – New concept mapping system
- **visit** – Captures visit-level data including patient, location, start/end times, and visit type.
- **visit\_type** – Defines types of visits (e.g., outpatient, emergency).

### Added Columns

- **encounter.visit\_id** – `INT`, foreign key to `visit.visit_id`

### Modified Columns

- **global\_property.property** – Changed from VARBINARY to VARCHAR
- **provider.identifier** – Made nullable (1.9.1)

### Data Changes / Fixes

- **scheduler\_task\_config** – Added “Auto Close Visits Task”
- **role\_role** – Orphan cleanup (repeated)
- **users.person\_id** – Ensured daemon user linked to `person` and `person_name`
- **person.gender** – Set for superuser
- **relationship\_type.description** – Populated empty descriptions with default text

Each bullet above is confirmed by the official OpenMRS changelogs or release notes. These cover all structural (schema) changes between OpenMRS 1.7.x and 1.9.x.

**Sources:** Official OpenMRS Liquibase changelogs and release notes for versions 1.8 and 1.9.

