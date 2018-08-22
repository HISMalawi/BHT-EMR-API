# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2014_02_21_071959) do

  create_table "active_list", primary_key: "active_list_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "active_list_type_id", null: false
    t.integer "person_id", null: false
    t.integer "concept_id", null: false
    t.integer "start_obs_id"
    t.integer "stop_obs_id"
    t.datetime "start_date", null: false
    t.datetime "end_date"
    t.string "comments"
    t.integer "creator", null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["active_list_type_id"], name: "active_list_type_of_active_list"
    t.index ["concept_id"], name: "concept_active_list"
    t.index ["creator"], name: "user_who_created_active_list"
    t.index ["person_id"], name: "person_of_active_list"
    t.index ["start_obs_id"], name: "start_obs_active_list"
    t.index ["stop_obs_id"], name: "stop_obs_active_list"
    t.index ["voided_by"], name: "user_who_voided_active_list"
  end

  create_table "active_list_allergy", primary_key: "active_list_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "allergy_type", limit: 50
    t.integer "reaction_concept_id"
    t.string "severity", limit: 50
    t.index ["reaction_concept_id"], name: "reaction_allergy"
  end

  create_table "active_list_problem", primary_key: "active_list_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "status", limit: 50
    t.float "sort_weight", limit: 53
  end

  create_table "active_list_type", primary_key: "active_list_type_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "name", limit: 50, null: false
    t.string "description"
    t.integer "creator", null: false
    t.datetime "date_created", null: false
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "user_who_created_active_list_type"
    t.index ["retired_by"], name: "user_who_retired_active_list_type"
  end

  create_table "cohort", primary_key: "cohort_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "description", limit: 1000
    t.integer "creator", null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_changed_cohort"
    t.index ["creator"], name: "cohort_creator"
    t.index ["uuid"], name: "cohort_uuid_index", unique: true
    t.index ["voided_by"], name: "user_who_voided_cohort"
  end

  create_table "cohort_member", primary_key: ["cohort_id", "patient_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "cohort_id", default: 0, null: false
    t.integer "patient_id", default: 0, null: false
    t.index ["cohort_id"], name: "cohort"
    t.index ["patient_id"], name: "patient"
  end

  create_table "complex_obs", primary_key: "obs_id", id: :integer, default: 0, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "mime_type_id", default: 0, null: false
    t.text "urn"
    t.text "complex_value", limit: 4294967295
    t.index ["mime_type_id"], name: "mime_type_of_content"
  end

  create_table "concept", primary_key: "concept_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "retired", limit: 2, default: 0, null: false
    t.string "short_name"
    t.text "description"
    t.text "form_text"
    t.integer "datatype_id", default: 0, null: false
    t.integer "class_id", default: 0, null: false
    t.integer "is_set", limit: 2, default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "default_charge"
    t.string "version", limit: 50
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_changed_concept"
    t.index ["class_id"], name: "concept_classes"
    t.index ["creator"], name: "concept_creator"
    t.index ["datatype_id"], name: "concept_datatypes"
    t.index ["retired_by"], name: "user_who_retired_concept"
    t.index ["uuid"], name: "concept_uuid_index", unique: true
  end

  create_table "concept_answer", primary_key: "concept_answer_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0, null: false
    t.integer "answer_concept"
    t.integer "answer_drug"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.string "uuid", limit: 38, null: false
    t.float "sort_weight", limit: 53
    t.index ["answer_concept"], name: "answer"
    t.index ["concept_id"], name: "answers_for_concept"
    t.index ["creator"], name: "answer_creator"
    t.index ["uuid"], name: "concept_answer_uuid_index", unique: true
  end

  create_table "concept_class", primary_key: "concept_class_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "description", default: "", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "concept_class_creator"
    t.index ["retired"], name: "concept_class_retired_status"
    t.index ["retired_by"], name: "user_who_retired_concept_class"
    t.index ["uuid"], name: "concept_class_uuid_index", unique: true
  end

  create_table "concept_complex", primary_key: "concept_id", id: :integer, default: nil, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "handler"
  end

  create_table "concept_datatype", primary_key: "concept_datatype_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "hl7_abbreviation", limit: 3
    t.string "description", default: "", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "concept_datatype_creator"
    t.index ["retired"], name: "concept_datatype_retired_status"
    t.index ["retired_by"], name: "user_who_retired_concept_datatype"
    t.index ["uuid"], name: "concept_datatype_uuid_index", unique: true
  end

  create_table "concept_derived", primary_key: "concept_id", id: :integer, default: 0, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "rule", limit: 16777215
    t.datetime "compile_date"
    t.string "compile_status"
    t.string "class_name", limit: 1024
  end

  create_table "concept_description", primary_key: "concept_description_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0, null: false
    t.text "description", null: false
    t.string "locale", limit: 50, default: "", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_changed_description"
    t.index ["concept_id"], name: "concept_being_described"
    t.index ["creator"], name: "user_who_created_description"
    t.index ["uuid"], name: "concept_description_uuid_index", unique: true
  end

  create_table "concept_map", primary_key: "concept_map_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "source"
    t.string "source_code"
    t.string "comment"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "concept_id", default: 0, null: false
    t.string "uuid", limit: 38, null: false
    t.index ["concept_id"], name: "map_for_concept"
    t.index ["creator"], name: "map_creator"
    t.index ["source"], name: "map_source"
    t.index ["uuid"], name: "concept_map_uuid_index", unique: true
  end

  create_table "concept_name", primary_key: "concept_name_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id"
    t.string "name", default: "", null: false
    t.string "locale", limit: 50, default: "", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.string "concept_name_type", limit: 50
    t.integer "locale_preferred", limit: 2, default: 0
    t.index ["concept_id"], name: "unique_concept_name_id"
    t.index ["concept_name_id"], name: "concept_name_id", unique: true
    t.index ["creator"], name: "user_who_created_name"
    t.index ["name"], name: "name_of_concept"
    t.index ["uuid"], name: "concept_name_uuid_index", unique: true
    t.index ["voided_by"], name: "user_who_voided_name"
  end

  create_table "concept_name_tag", primary_key: "concept_name_tag_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "tag", limit: 50, null: false
    t.text "description", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["concept_name_tag_id"], name: "concept_name_tag_id", unique: true
    t.index ["concept_name_tag_id"], name: "concept_name_tag_id_2", unique: true
    t.index ["creator"], name: "user_who_created_name_tag"
    t.index ["tag"], name: "concept_name_tag_unique_tags", unique: true
    t.index ["uuid"], name: "concept_name_tag_uuid_index", unique: true
    t.index ["voided_by"], name: "user_who_voided_name_tag"
  end

  create_table "concept_name_tag_map", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_name_id", null: false
    t.integer "concept_name_tag_id", null: false
    t.index ["concept_name_id"], name: "map_name"
    t.index ["concept_name_tag_id"], name: "map_name_tag"
  end

  create_table "concept_numeric", primary_key: "concept_id", id: :integer, default: 0, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.float "hi_absolute", limit: 53
    t.float "hi_critical", limit: 53
    t.float "hi_normal", limit: 53
    t.float "low_absolute", limit: 53
    t.float "low_critical", limit: 53
    t.float "low_normal", limit: 53
    t.string "units", limit: 50
    t.integer "precise", limit: 2, default: 0, null: false
  end

  create_table "concept_proposal", primary_key: "concept_proposal_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id"
    t.integer "encounter_id"
    t.string "original_text", default: "", null: false
    t.string "final_text"
    t.integer "obs_id"
    t.integer "obs_concept_id"
    t.string "state", limit: 32, default: "UNMAPPED", null: false, comment: "Valid values are: UNMAPPED, SYNONYM, CONCEPT, REJECT"
    t.string "comments", comment: "Comment from concept admin/mapper"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "locale", limit: 50, default: "", null: false
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_changed_proposal"
    t.index ["concept_id"], name: "concept_for_proposal"
    t.index ["creator"], name: "user_who_created_proposal"
    t.index ["encounter_id"], name: "encounter_for_proposal"
    t.index ["obs_concept_id"], name: "proposal_obs_concept_id"
    t.index ["obs_id"], name: "proposal_obs_id"
    t.index ["uuid"], name: "concept_proposal_uuid_index", unique: true
  end

  create_table "concept_proposal_tag_map", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_proposal_id", null: false
    t.integer "concept_name_tag_id", null: false
    t.index ["concept_name_tag_id"], name: "map_name_tag"
    t.index ["concept_proposal_id"], name: "map_proposal"
  end

  create_table "concept_set", primary_key: "concept_set_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0, null: false
    t.integer "concept_set", default: 0, null: false
    t.float "sort_weight", limit: 53
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.string "uuid", limit: 38, null: false
    t.index ["concept_id"], name: "idx_concept_set_concept"
    t.index ["concept_set"], name: "has_a"
    t.index ["creator"], name: "user_who_created"
    t.index ["uuid"], name: "concept_set_uuid_index", unique: true
  end

  create_table "concept_set_derived", primary_key: ["concept_id", "concept_set"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0, null: false
    t.integer "concept_set", default: 0, null: false
    t.float "sort_weight", limit: 53
  end

  create_table "concept_source", primary_key: "concept_source_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", limit: 50, default: "", null: false
    t.text "description", null: false
    t.string "hl7_code", limit: 50
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.boolean "retired", null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "concept_source_creator"
    t.index ["hl7_code", "retired"], name: "unique_hl7_code"
    t.index ["retired_by"], name: "user_who_voided_concept_source"
    t.index ["uuid"], name: "concept_source_uuid_index", unique: true
  end

  create_table "concept_state_conversion", primary_key: "concept_state_conversion_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0
    t.integer "program_workflow_id", default: 0
    t.integer "program_workflow_state_id", default: 0
    t.string "uuid", limit: 38, null: false
    t.index ["concept_id"], name: "triggering_concept"
    t.index ["program_workflow_id", "concept_id"], name: "unique_workflow_concept_in_conversion", unique: true
    t.index ["program_workflow_id"], name: "affected_workflow"
    t.index ["program_workflow_state_id"], name: "resulting_state"
    t.index ["uuid"], name: "concept_state_conversion_uuid_index", unique: true
  end

  create_table "concept_synonym", primary_key: ["synonym", "concept_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0, null: false
    t.string "synonym", default: "", null: false
    t.string "locale"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.index ["concept_id"], name: "synonym_for"
    t.index ["creator"], name: "synonym_creator"
  end

  create_table "concept_word", primary_key: "concept_word_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0, null: false
    t.string "word", limit: 50, default: "", null: false
    t.string "locale", limit: 20, default: "", null: false
    t.integer "concept_name_id", null: false
    t.index ["concept_id"], name: "concept_word_concept_idx"
    t.index ["concept_name_id"], name: "word_for_name"
    t.index ["word"], name: "word_in_concept_name"
  end

  create_table "district", primary_key: "district_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.integer "region_id", default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.index ["creator"], name: "user_who_created_district"
    t.index ["region_id"], name: "region_for_district"
    t.index ["retired"], name: "retired_status"
    t.index ["retired_by"], name: "user_who_retired_district"
  end

  create_table "districts", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "drug", primary_key: "drug_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0, null: false
    t.string "name", limit: 50
    t.integer "combination", limit: 2, default: 0, null: false
    t.integer "dosage_form"
    t.float "dose_strength", limit: 53
    t.float "maximum_daily_dose", limit: 53
    t.float "minimum_daily_dose", limit: 53
    t.integer "route"
    t.string "units", limit: 50
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["concept_id"], name: "primary_drug_concept"
    t.index ["creator"], name: "drug_creator"
    t.index ["dosage_form"], name: "dosage_form_concept"
    t.index ["retired_by"], name: "user_who_voided_drug"
    t.index ["route"], name: "route_concept"
    t.index ["uuid"], name: "drug_uuid_index", unique: true
  end

  create_table "drug_cms", primary_key: "drug_inventory_id", id: :integer, default: nil, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "name", null: false
    t.string "code"
    t.string "short_name", limit: 225
    t.string "tabs", limit: 225
    t.integer "pack_size"
    t.integer "weight"
    t.string "strength"
    t.integer "voided", limit: 1, default: 0
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason", limit: 225
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "drug_ingredient", primary_key: ["ingredient_id", "concept_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0, null: false
    t.integer "ingredient_id", default: 0, null: false
    t.index ["concept_id"], name: "combination_drug"
  end

  create_table "drug_ingredients", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "drug_order", primary_key: "order_id", id: :integer, default: 0, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "drug_inventory_id", default: 0
    t.float "dose", limit: 53
    t.float "equivalent_daily_dose", limit: 53
    t.string "units"
    t.string "frequency"
    t.integer "prn", limit: 2, default: 0, null: false
    t.integer "complex", limit: 2, default: 0, null: false
    t.integer "quantity"
    t.index ["drug_inventory_id"], name: "inventory_item"
  end

  create_table "drug_order_barcodes", primary_key: "drug_order_barcode_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "drug_id"
    t.integer "tabs"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "encounter", primary_key: "encounter_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "encounter_type", null: false
    t.integer "patient_id", default: 0, null: false
    t.integer "provider_id", default: 0, null: false
    t.integer "location_id"
    t.integer "form_id"
    t.datetime "encounter_datetime", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.index ["changed_by"], name: "encounter_changed_by"
    t.index ["creator"], name: "encounter_creator"
    t.index ["encounter_datetime"], name: "encounter_datetime_idx"
    t.index ["encounter_type"], name: "encounter_type_id"
    t.index ["form_id"], name: "encounter_form"
    t.index ["location_id"], name: "encounter_location"
    t.index ["patient_id"], name: "encounter_patient"
    t.index ["provider_id"], name: "encounter_provider"
    t.index ["uuid"], name: "encounter_uuid_index", unique: true
    t.index ["voided_by"], name: "user_who_voided_encounter"
  end

  create_table "encounter_type", primary_key: "encounter_type_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", limit: 50, default: "", null: false
    t.text "description"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "user_who_created_type"
    t.index ["retired"], name: "retired_status"
    t.index ["retired_by"], name: "user_who_retired_encounter_type"
    t.index ["uuid"], name: "encounter_type_uuid_index", unique: true
  end

  create_table "external_source", primary_key: "external_source_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "source", default: 0, null: false
    t.string "source_code", null: false
    t.string "name"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.index ["creator"], name: "map_ext_creator"
    t.index ["source"], name: "map_ext_source"
  end

  create_table "field", primary_key: "field_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.text "description"
    t.integer "field_type"
    t.integer "concept_id"
    t.string "table_name", limit: 50
    t.string "attribute_name", limit: 50
    t.text "default_value"
    t.integer "select_multiple", limit: 2, default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_changed_field"
    t.index ["concept_id"], name: "concept_for_field"
    t.index ["creator"], name: "user_who_created_field"
    t.index ["field_type"], name: "type_of_field"
    t.index ["retired"], name: "field_retired_status"
    t.index ["retired_by"], name: "user_who_retired_field"
    t.index ["uuid"], name: "field_uuid_index", unique: true
  end

  create_table "field_answer", primary_key: ["field_id", "answer_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "field_id", default: 0, null: false
    t.integer "answer_id", default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.string "uuid", limit: 38, null: false
    t.index ["answer_id"], name: "field_answer_concept"
    t.index ["creator"], name: "user_who_created_field_answer"
    t.index ["field_id"], name: "answers_for_field"
    t.index ["uuid"], name: "field_answer_uuid_index", unique: true
  end

  create_table "field_type", primary_key: "field_type_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", limit: 50
    t.text "description", limit: 4294967295
    t.integer "is_set", limit: 2, default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "user_who_created_field_type"
    t.index ["uuid"], name: "field_type_uuid_index", unique: true
  end

  create_table "form", primary_key: "form_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "version", limit: 50, default: "", null: false
    t.integer "build"
    t.integer "published", limit: 2, default: 0, null: false
    t.text "description"
    t.integer "encounter_type"
    t.text "template", limit: 16777215
    t.text "xslt", limit: 16777215
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retired_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_last_changed_form"
    t.index ["creator"], name: "user_who_created_form"
    t.index ["encounter_type"], name: "encounter_type"
    t.index ["retired_by"], name: "user_who_retired_form"
    t.index ["uuid"], name: "form_uuid_index", unique: true
  end

  create_table "form2program_map", primary_key: ["program", "encounter_type"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "program", null: false
    t.integer "encounter_type", null: false
    t.integer "creator", null: false
    t.datetime "date_created", null: false
    t.integer "changed_by", null: false
    t.datetime "date_changed", null: false
    t.boolean "applied", default: false, null: false
    t.index ["changed_by"], name: "user_who_changed_form2program"
    t.index ["creator"], name: "user_who_created_form2program"
    t.index ["encounter_type"], name: "encounter_type"
  end

  create_table "form_field", primary_key: "form_field_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "form_id", default: 0, null: false
    t.integer "field_id", default: 0, null: false
    t.integer "field_number"
    t.string "field_part", limit: 5
    t.integer "page_number"
    t.integer "parent_form_field"
    t.integer "min_occurs"
    t.integer "max_occurs"
    t.integer "required", limit: 2, default: 0, null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.float "sort_weight"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_last_changed_form_field"
    t.index ["creator"], name: "user_who_created_form_field"
    t.index ["field_id"], name: "field_within_form"
    t.index ["form_id"], name: "form_containing_field"
    t.index ["parent_form_field"], name: "form_field_hierarchy"
    t.index ["uuid"], name: "form_field_uuid_index", unique: true
  end

  create_table "formentry_archive", primary_key: "formentry_archive_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "form_data", limit: 16777215, null: false
    t.datetime "date_created", null: false
    t.integer "creator", default: 0, null: false
    t.index ["creator"], name: "User who created formentry_archive"
  end

  create_table "formentry_error", primary_key: "formentry_error_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "form_data", limit: 16777215, null: false
    t.string "error", default: "", null: false
    t.text "error_details"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.index ["creator"], name: "User who created formentry_error"
  end

  create_table "formentry_queue", primary_key: "formentry_queue_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "form_data", limit: 16777215, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
  end

  create_table "formentry_xsn", primary_key: "formentry_xsn_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "form_id", null: false
    t.binary "xsn_data", limit: 4294967295, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "archived", default: 0, null: false
    t.integer "archived_by"
    t.datetime "date_archived"
    t.index ["archived_by"], name: "User who archived formentry_xsn"
    t.index ["creator"], name: "User who created formentry_xsn"
    t.index ["form_id"], name: "Form with which this xsn is related"
  end

  create_table "global_property", primary_key: "property", id: :binary, limit: 255, default: "", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "property_value", limit: 16777215
    t.text "description"
    t.string "uuid", limit: 38, null: false
    t.index ["uuid"], name: "global_property_uuid_index", unique: true
  end

  create_table "heart_beat", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "ip", limit: 20
    t.string "property", limit: 200
    t.string "value", limit: 200
    t.datetime "time_stamp"
    t.string "username", limit: 10
    t.string "url", limit: 100
  end

  create_table "hl7_in_archive", primary_key: "hl7_in_archive_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "hl7_source", default: 0, null: false
    t.string "hl7_source_key"
    t.text "hl7_data", limit: 16777215, null: false
    t.datetime "date_created", null: false
    t.integer "message_state", default: 2
    t.string "uuid", limit: 38, null: false
    t.index ["message_state"], name: "hl7_in_archive_message_state_idx"
    t.index ["uuid"], name: "hl7_in_archive_uuid_index", unique: true
  end

  create_table "hl7_in_error", primary_key: "hl7_in_error_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "hl7_source", default: 0, null: false
    t.text "hl7_source_key"
    t.text "hl7_data", limit: 16777215, null: false
    t.string "error", default: "", null: false
    t.text "error_details"
    t.datetime "date_created", null: false
    t.string "uuid", limit: 38, null: false
    t.index ["uuid"], name: "hl7_in_error_uuid_index", unique: true
  end

  create_table "hl7_in_queue", primary_key: "hl7_in_queue_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "hl7_source", default: 0, null: false
    t.text "hl7_source_key"
    t.text "hl7_data", limit: 16777215, null: false
    t.integer "message_state", default: 0, null: false
    t.datetime "date_processed"
    t.text "error_msg"
    t.datetime "date_created"
    t.string "uuid", limit: 38, null: false
    t.index ["hl7_source"], name: "hl7_source"
    t.index ["uuid"], name: "hl7_in_queue_uuid_index", unique: true
  end

  create_table "hl7_source", primary_key: "hl7_source_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.text "description", limit: 255
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "creator"
    t.index ["uuid"], name: "hl7_source_uuid_index", unique: true
  end

  create_table "htmlformentry_html_form", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "form_id"
    t.string "name", limit: 100, null: false
    t.text "xml_data", limit: 16777215, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.boolean "retired", default: false, null: false
    t.index ["changed_by"], name: "User who changed htmlformentry_htmlform"
    t.index ["creator"], name: "User who created htmlformentry_htmlform"
    t.index ["form_id"], name: "Form with which this htmlform is related"
  end

  create_table "labs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "liquibasechangelog", primary_key: ["ID", "AUTHOR", "FILENAME"], options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "ID", limit: 63, null: false
    t.string "AUTHOR", limit: 63, null: false
    t.string "FILENAME", limit: 200, null: false
    t.datetime "DATEEXECUTED", null: false
    t.string "MD5SUM", limit: 32
    t.string "DESCRIPTION"
    t.string "COMMENTS"
    t.string "TAG"
    t.string "LIQUIBASE", limit: 10
  end

  create_table "liquibasechangeloglock", primary_key: "ID", id: :integer, default: nil, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.boolean "LOCKED", null: false
    t.datetime "LOCKGRANTED"
    t.string "LOCKEDBY"
  end

  create_table "location", primary_key: "location_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "description"
    t.string "address1", limit: 50
    t.string "address2", limit: 50
    t.string "city_village", limit: 50
    t.string "state_province", limit: 50
    t.string "postal_code", limit: 50
    t.string "country", limit: 50
    t.string "latitude", limit: 50
    t.string "longitude", limit: 50
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.string "county_district", limit: 50
    t.string "neighborhood_cell", limit: 50
    t.string "region", limit: 50
    t.string "subregion", limit: 50
    t.string "township_division", limit: 50
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.integer "location_type_id"
    t.integer "parent_location"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "user_who_created_location"
    t.index ["location_type_id"], name: "type_of_location"
    t.index ["name"], name: "name_of_location"
    t.index ["parent_location"], name: "parent_location"
    t.index ["retired"], name: "retired_status"
    t.index ["retired_by"], name: "user_who_retired_location"
    t.index ["uuid"], name: "location_uuid_index", unique: true
  end

  create_table "location_tag", primary_key: "location_tag_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "name", limit: 50
    t.string "description"
    t.integer "creator", null: false
    t.datetime "date_created", null: false
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "location_tag_creator"
    t.index ["retired_by"], name: "location_tag_retired_by"
    t.index ["uuid"], name: "location_tag_uuid_index", unique: true
  end

  create_table "location_tag_map", primary_key: ["location_id", "location_tag_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "location_id", null: false
    t.integer "location_tag_id", null: false
    t.index ["location_tag_id"], name: "location_tag_map_tag"
  end

  create_table "location_tag_maps", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "location_tags", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "logic_rule_definition", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "uuid", limit: 38, null: false
    t.string "name", null: false
    t.string "description", limit: 1000
    t.string "rule_content", limit: 2048, null: false
    t.string "language", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.index ["changed_by"], name: "changed_by for rule_definition"
    t.index ["creator"], name: "creator for rule_definition"
    t.index ["name"], name: "name", unique: true
    t.index ["retired_by"], name: "retired_by for rule_definition"
  end

  create_table "logic_rule_token", primary_key: "logic_rule_token_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "creator", null: false
    t.datetime "date_created", default: "0002-11-30 00:00:00", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "token", limit: 512, null: false
    t.string "class_name", limit: 512, null: false
    t.string "state", limit: 512
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "token_changed_by"
    t.index ["creator"], name: "token_creator"
    t.index ["uuid"], name: "logic_rule_token_uuid", unique: true
  end

  create_table "logic_rule_token_tag", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "logic_rule_token_id", null: false
    t.string "tag", limit: 512, null: false
    t.index ["logic_rule_token_id"], name: "token_tag"
  end

  create_table "logic_token_registration", primary_key: "token_registration_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "creator", null: false
    t.datetime "date_created", default: "0002-11-30 00:00:00", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "token", limit: 512, null: false
    t.string "provider_class_name", limit: 512, null: false
    t.string "provider_token", limit: 512, null: false
    t.string "configuration", limit: 2000
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "token_registration_changed_by"
    t.index ["creator"], name: "token_registration_creator"
    t.index ["uuid"], name: "uuid", unique: true
  end

  create_table "logic_token_registration_tag", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "token_registration_id", null: false
    t.string "tag", limit: 512, null: false
    t.index ["token_registration_id"], name: "token_registration_tag"
  end

  create_table "merged_patients", primary_key: "patient_id", id: :integer, default: nil, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "merged_to_id", null: false
  end

  create_table "mime_type", primary_key: "mime_type_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "mime_type", limit: 75, default: "", null: false
    t.text "description"
    t.index ["mime_type_id"], name: "mime_type_id"
  end

  create_table "national_id", id: :integer, options: "ENGINE=MyISAM DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "national_id", limit: 30, default: "", null: false
    t.boolean "assigned", default: false, null: false
    t.boolean "eds", default: false
    t.integer "creator"
    t.datetime "date_issued"
    t.text "issued_to"
  end

  create_table "national_ids", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "note", primary_key: "note_id", id: :integer, default: 0, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "note_type", limit: 50
    t.integer "patient_id"
    t.integer "obs_id"
    t.integer "encounter_id"
    t.text "text", null: false
    t.integer "priority"
    t.integer "parent"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_changed_note"
    t.index ["creator"], name: "user_who_created_note"
    t.index ["encounter_id"], name: "encounter_note"
    t.index ["obs_id"], name: "obs_note"
    t.index ["parent"], name: "note_hierarchy"
    t.index ["patient_id"], name: "patient_note"
    t.index ["uuid"], name: "note_uuid_index", unique: true
  end

  create_table "notification_alert", primary_key: "alert_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "text", limit: 512, null: false
    t.integer "satisfied_by_any", default: 0, null: false
    t.integer "alert_read", default: 0, null: false
    t.datetime "date_to_expire"
    t.integer "creator", null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_changed_alert"
    t.index ["creator"], name: "alert_creator"
    t.index ["uuid"], name: "notification_alert_uuid_index", unique: true
  end

  create_table "notification_alert_recipient", primary_key: ["alert_id", "user_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "alert_id", null: false
    t.integer "user_id", null: false
    t.integer "alert_read", default: 0, null: false
    t.timestamp "date_changed", default: -> { "CURRENT_TIMESTAMP" }
    t.string "uuid", limit: 38, null: false
    t.index ["alert_id"], name: "id_of_alert"
    t.index ["user_id"], name: "alert_read_by_user"
  end

  create_table "notification_template", primary_key: "template_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", limit: 50
    t.text "template"
    t.string "subject", limit: 100
    t.string "sender"
    t.string "recipients", limit: 512
    t.integer "ordinal", default: 0
    t.string "uuid", limit: 38, null: false
    t.index ["uuid"], name: "notification_template_uuid_index", unique: true
  end

  create_table "obs", primary_key: "obs_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "person_id", null: false
    t.integer "concept_id", default: 0, null: false
    t.integer "encounter_id"
    t.integer "order_id"
    t.datetime "obs_datetime", null: false
    t.integer "location_id"
    t.integer "obs_group_id"
    t.string "accession_number"
    t.integer "value_group_id"
    t.boolean "value_boolean"
    t.integer "value_coded"
    t.integer "value_coded_name_id"
    t.integer "value_drug"
    t.datetime "value_datetime"
    t.float "value_numeric", limit: 53
    t.string "value_modifier", limit: 2
    t.text "value_text"
    t.datetime "date_started"
    t.datetime "date_stopped"
    t.string "comments"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "value_complex"
    t.string "uuid", limit: 38, null: false
    t.index ["concept_id"], name: "obs_concept"
    t.index ["creator"], name: "obs_enterer"
    t.index ["encounter_id"], name: "encounter_observations"
    t.index ["location_id"], name: "obs_location"
    t.index ["obs_datetime"], name: "obs_datetime_idx"
    t.index ["obs_group_id"], name: "obs_grouping_id"
    t.index ["order_id"], name: "obs_order"
    t.index ["person_id"], name: "patient_obs"
    t.index ["uuid"], name: "obs_uuid_index", unique: true
    t.index ["value_coded"], name: "answer_concept"
    t.index ["value_coded_name_id"], name: "obs_name_of_coded_value"
    t.index ["value_drug"], name: "answer_concept_drug"
    t.index ["voided_by"], name: "user_who_voided_obs"
  end

  create_table "order_extension", primary_key: "order_extension_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "order_id", null: false
    t.string "value", limit: 50, default: "", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.boolean "voided", default: false, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.index ["creator"], name: "user_who_created_ext"
    t.index ["voided"], name: "retired_status"
    t.index ["voided_by"], name: "user_who_retired_ext"
  end

  create_table "order_type", primary_key: "order_type_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "description", default: "", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "type_created_by"
    t.index ["retired"], name: "retired_status"
    t.index ["retired_by"], name: "user_who_retired_order_type"
    t.index ["uuid"], name: "order_type_uuid_index", unique: true
  end

  create_table "orders", primary_key: "order_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "order_type_id", default: 0, null: false
    t.integer "concept_id", default: 0, null: false
    t.integer "orderer", default: 0
    t.integer "encounter_id"
    t.text "instructions"
    t.datetime "start_date"
    t.datetime "auto_expire_date"
    t.integer "discontinued", limit: 2, default: 0, null: false
    t.datetime "discontinued_date"
    t.integer "discontinued_by"
    t.integer "discontinued_reason"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.integer "patient_id", null: false
    t.string "accession_number"
    t.integer "obs_id"
    t.string "uuid", limit: 38, null: false
    t.string "discontinued_reason_non_coded"
    t.index ["creator"], name: "order_creator"
    t.index ["discontinued_by"], name: "user_who_discontinued_order"
    t.index ["discontinued_reason"], name: "discontinued_because"
    t.index ["encounter_id"], name: "orders_in_encounter"
    t.index ["obs_id"], name: "obs_for_order"
    t.index ["order_type_id"], name: "type_of_order"
    t.index ["orderer"], name: "orderer_not_drug"
    t.index ["patient_id"], name: "order_for_patient"
    t.index ["uuid"], name: "orders_uuid_index", unique: true
    t.index ["voided_by"], name: "user_who_voided_order"
  end

  create_table "outpatients", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "patient", primary_key: "patient_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "tribe"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.index ["changed_by"], name: "user_who_changed_pat"
    t.index ["creator"], name: "user_who_created_patient"
    t.index ["tribe"], name: "belongs_to_tribe"
    t.index ["voided_by"], name: "user_who_voided_patient"
  end

  create_table "patient_defaulted_dates", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "patient_id"
    t.integer "order_id"
    t.integer "drug_id"
    t.float "equivalent_daily_dose"
    t.integer "amount_dispensed"
    t.integer "quantity_given"
    t.date "start_date"
    t.date "end_date"
    t.date "defaulted_date"
    t.date "date_created", default: "2016-01-12"
  end

  create_table "patient_identifier", primary_key: "patient_identifier_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "patient_id", default: 0, null: false
    t.string "identifier", limit: 50, default: "", null: false
    t.integer "identifier_type", default: 0, null: false
    t.integer "preferred", limit: 2, default: 0, null: false
    t.integer "location_id", default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "identifier_creator"
    t.index ["identifier"], name: "identifier_name"
    t.index ["identifier_type"], name: "defines_identifier_type"
    t.index ["location_id"], name: "identifier_location"
    t.index ["patient_id"], name: "idx_patient_identifier_patient"
    t.index ["uuid"], name: "patient_identifier_uuid_index", unique: true
    t.index ["voided_by"], name: "identifier_voider"
  end

  create_table "patient_identifier_type", primary_key: "patient_identifier_type_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", limit: 50, default: "", null: false
    t.text "description", null: false
    t.string "format", limit: 50
    t.integer "check_digit", limit: 2, default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "required", limit: 2, default: 0, null: false
    t.string "format_description"
    t.string "validator", limit: 200
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "type_creator"
    t.index ["retired"], name: "retired_status"
    t.index ["retired_by"], name: "user_who_retired_patient_identifier_type"
    t.index ["uuid"], name: "patient_identifier_type_uuid_index", unique: true
  end

  create_table "patient_program", primary_key: "patient_program_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "patient_id", default: 0, null: false
    t.integer "program_id", default: 0, null: false
    t.datetime "date_enrolled"
    t.datetime "date_completed"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.integer "location_id"
    t.index ["changed_by"], name: "user_who_changed"
    t.index ["creator"], name: "patient_program_creator"
    t.index ["patient_id"], name: "patient_in_program"
    t.index ["program_id"], name: "program_for_patient"
    t.index ["uuid"], name: "patient_program_uuid_index", unique: true
    t.index ["voided_by"], name: "user_who_voided_patient_program"
  end

  create_table "patient_state", primary_key: "patient_state_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "patient_program_id", default: 0, null: false
    t.integer "state", default: 0, null: false
    t.date "start_date"
    t.date "end_date"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "patient_state_changer"
    t.index ["creator"], name: "patient_state_creator"
    t.index ["patient_program_id"], name: "patient_program_for_state"
    t.index ["state"], name: "state_for_patient"
    t.index ["uuid"], name: "patient_state_uuid_index", unique: true
    t.index ["voided_by"], name: "patient_state_voider"
  end

  create_table "patientflags_flag", primary_key: "flag_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "criteria", limit: 5000, null: false
    t.string "message", null: false
    t.boolean "enabled", null: false
    t.string "evaluator", null: false
    t.string "description", limit: 1000
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
  end

  create_table "patientflags_flag_tag", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "flag_id", null: false
    t.integer "tag_id", null: false
    t.index ["flag_id"], name: "flag_id"
    t.index ["tag_id"], name: "tag_id"
  end

  create_table "patientflags_tag", primary_key: "tag_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "tag", null: false
    t.string "description", limit: 1000
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
  end

  create_table "patients_for_location", primary_key: "patient_id", id: :integer, default: nil, options: "ENGINE=MyISAM DEFAULT CHARSET=utf8", force: :cascade do |t|
  end

  create_table "patients_to_merge", id: false, options: "ENGINE=MyISAM DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "patient_id"
    t.integer "to_merge_to_id"
  end

  create_table "person", primary_key: "person_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "gender", limit: 50, default: ""
    t.date "birthdate"
    t.integer "birthdate_estimated", limit: 2, default: 0, null: false
    t.integer "dead", limit: 2, default: 0, null: false
    t.datetime "death_date"
    t.integer "cause_of_death"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["birthdate"], name: "person_birthdate"
    t.index ["cause_of_death"], name: "person_died_because"
    t.index ["changed_by"], name: "user_who_changed_pat"
    t.index ["creator"], name: "user_who_created_patient"
    t.index ["death_date"], name: "person_death_date"
    t.index ["uuid"], name: "person_uuid_index", unique: true
    t.index ["voided_by"], name: "user_who_voided_patient"
  end

  create_table "person_address", primary_key: "person_address_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "person_id"
    t.integer "preferred", limit: 2, default: 0, null: false
    t.string "address1", limit: 50
    t.string "address2", limit: 50
    t.string "city_village", limit: 50
    t.string "state_province", limit: 50
    t.string "postal_code", limit: 50
    t.string "country", limit: 50
    t.string "latitude", limit: 50
    t.string "longitude", limit: 50
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "county_district", limit: 50
    t.string "neighborhood_cell", limit: 50
    t.string "region", limit: 50
    t.string "subregion", limit: 50
    t.string "township_division", limit: 50
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "patient_address_creator"
    t.index ["date_created"], name: "index_date_created_on_person_address"
    t.index ["person_id"], name: "patient_addresses"
    t.index ["uuid"], name: "person_address_uuid_index", unique: true
    t.index ["voided_by"], name: "patient_address_void"
  end

  create_table "person_attribute", primary_key: "person_attribute_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "person_id", default: 0, null: false
    t.string "value", limit: 50, default: "", null: false
    t.integer "person_attribute_type_id", default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "attribute_changer"
    t.index ["creator"], name: "attribute_creator"
    t.index ["person_attribute_type_id"], name: "defines_attribute_type"
    t.index ["person_id"], name: "identifies_person"
    t.index ["uuid"], name: "person_attribute_uuid_index", unique: true
    t.index ["voided_by"], name: "attribute_voider"
  end

  create_table "person_attribute_type", primary_key: "person_attribute_type_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", limit: 50, default: "", null: false
    t.text "description", null: false
    t.string "format", limit: 50
    t.integer "foreign_key"
    t.integer "searchable", limit: 2, default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "edit_privilege"
    t.string "uuid", limit: 38, null: false
    t.float "sort_weight", limit: 53
    t.index ["changed_by"], name: "attribute_type_changer"
    t.index ["creator"], name: "type_creator"
    t.index ["edit_privilege"], name: "privilege_which_can_edit"
    t.index ["name"], name: "name_of_attribute"
    t.index ["retired"], name: "person_attribute_type_retired_status"
    t.index ["retired_by"], name: "user_who_retired_person_attribute_type"
    t.index ["searchable"], name: "attribute_is_searchable"
    t.index ["uuid"], name: "person_attribute_type_uuid_index", unique: true
  end

  create_table "person_name", primary_key: "person_name_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "preferred", limit: 2, default: 0, null: false
    t.integer "person_id"
    t.string "prefix", limit: 50
    t.string "given_name", limit: 50
    t.string "middle_name", limit: 50
    t.string "family_name_prefix", limit: 50
    t.string "family_name", limit: 50
    t.string "family_name2", limit: 50
    t.string "family_name_suffix", limit: 50
    t.string "degree", limit: 50
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "user_who_made_name"
    t.index ["family_name"], name: "last_name"
    t.index ["family_name2"], name: "family_name2"
    t.index ["given_name"], name: "first_name"
    t.index ["middle_name"], name: "middle_name"
    t.index ["person_id"], name: "name_for_patient"
    t.index ["uuid"], name: "person_name_uuid_index", unique: true
    t.index ["voided_by"], name: "user_who_voided_name"
  end

  create_table "person_name_code", primary_key: "person_name_code_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "person_name_id"
    t.string "given_name_code", limit: 50
    t.string "middle_name_code", limit: 50
    t.string "family_name_code", limit: 50
    t.string "family_name2_code", limit: 50
    t.string "family_name_suffix_code", limit: 50
    t.index ["family_name_code"], name: "family_name_code"
    t.index ["given_name_code", "family_name_code"], name: "given_family_name_code"
    t.index ["given_name_code"], name: "given_name_code"
    t.index ["middle_name_code"], name: "middle_name_code"
    t.index ["person_name_id"], name: "name_for_patient"
  end

  create_table "pharmacies", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "pharmacy_encounter_type", primary_key: "pharmacy_encounter_type_id", id: :integer, options: "ENGINE=MyISAM DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "name", limit: 50, null: false
    t.text "description", null: false
    t.string "format", limit: 50
    t.integer "foreign_key"
    t.boolean "searchable"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason", limit: 225
  end

  create_table "pharmacy_obs", primary_key: "pharmacy_module_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "pharmacy_encounter_type", default: 0, null: false
    t.integer "drug_id", default: 0, null: false
    t.float "value_numeric", limit: 53
    t.integer "value_coded"
    t.string "value_text", limit: 15
    t.date "expiry_date"
    t.date "encounter_date", null: false
    t.integer "creator", null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.boolean "voided", default: false, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason", limit: 225
  end

  create_table "privilege", primary_key: "privilege", id: :string, limit: 50, default: "", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "description", limit: 250, default: "", null: false
    t.string "uuid", limit: 38, null: false
    t.index ["uuid"], name: "privilege_uuid_index", unique: true
  end

  create_table "program", primary_key: "program_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "retired", limit: 2, default: 0, null: false
    t.string "name", limit: 50, null: false
    t.string "description", limit: 500
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_changed_program"
    t.index ["concept_id"], name: "program_concept"
    t.index ["creator"], name: "program_creator"
    t.index ["uuid"], name: "program_uuid_index", unique: true
  end

  create_table "program_encounter", primary_key: "program_encounter_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "patient_id"
    t.datetime "date_time"
    t.integer "program_id"
  end

  create_table "program_encounter_details", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "encounter_id"
    t.integer "program_encounter_id"
    t.integer "program_id"
    t.integer "voided", default: 0
  end

  create_table "program_encounter_type_map", primary_key: "program_encounter_type_map_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "program_id"
    t.integer "encounter_type_id"
    t.index ["encounter_type_id"], name: "referenced_encounter_type"
    t.index ["program_id", "encounter_type_id"], name: "program_mapping"
  end

  create_table "program_location_restriction", primary_key: "program_location_restriction_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "program_id"
    t.integer "location_id"
    t.index ["location_id"], name: "referenced_location"
    t.index ["program_id", "location_id"], name: "program_mapping"
  end

  create_table "program_orders_map", primary_key: "program_orders_map_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "program_id"
    t.integer "concept_id"
    t.index ["concept_id"], name: "referenced_concept_id"
    t.index ["program_id", "concept_id"], name: "program_mapping"
  end

  create_table "program_patient_identifier_type_map", primary_key: "program_patient_identifier_type_map_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "program_id"
    t.integer "patient_identifier_type_id"
    t.index ["patient_identifier_type_id"], name: "referenced_patient_identifier_type"
    t.index ["program_id", "patient_identifier_type_id"], name: "program_mapping"
  end

  create_table "program_relationship_type_map", primary_key: "program_relationship_type_map_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "program_id"
    t.integer "relationship_type_id"
    t.index ["program_id", "relationship_type_id"], name: "program_mapping"
    t.index ["relationship_type_id"], name: "referenced_relationship_type"
  end

  create_table "program_workflow", primary_key: "program_workflow_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "program_id", default: 0, null: false
    t.integer "concept_id", default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "workflow_voided_by"
    t.index ["concept_id"], name: "workflow_concept"
    t.index ["creator"], name: "workflow_creator"
    t.index ["program_id"], name: "program_for_workflow"
    t.index ["uuid"], name: "program_workflow_uuid_index", unique: true
  end

  create_table "program_workflow_state", primary_key: "program_workflow_state_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "program_workflow_id", default: 0, null: false
    t.integer "concept_id", default: 0, null: false
    t.integer "initial", limit: 2, default: 0, null: false
    t.integer "terminal", limit: 2, default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "state_voided_by"
    t.index ["concept_id"], name: "state_concept"
    t.index ["creator"], name: "state_creator"
    t.index ["program_workflow_id"], name: "workflow_for_state"
    t.index ["uuid"], name: "program_workflow_state_uuid_index", unique: true
  end

  create_table "regimen", primary_key: "regimen_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "concept_id", default: 0, null: false
    t.string "regimen_index", limit: 5
    t.integer "min_weight", default: 0, null: false
    t.integer "max_weight", default: 200, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "retired", limit: 2, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.integer "program_id", default: 0, null: false
    t.index ["concept_id"], name: "map_concept"
  end

  create_table "regimen_drug_order", primary_key: "regimen_drug_order_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "regimen_id", default: 0, null: false
    t.integer "drug_inventory_id", default: 0
    t.float "dose", limit: 53
    t.float "equivalent_daily_dose", limit: 53
    t.string "units"
    t.string "frequency"
    t.boolean "prn", default: false, null: false
    t.boolean "complex", default: false, null: false
    t.integer "quantity"
    t.text "instructions"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["creator"], name: "regimen_drug_order_creator"
    t.index ["drug_inventory_id"], name: "map_drug_inventory"
    t.index ["regimen_id"], name: "map_regimen"
    t.index ["uuid"], name: "regimen_drug_order_uuid_index", unique: true
    t.index ["voided_by"], name: "user_who_voided_regimen_drug_order"
  end

  create_table "region", primary_key: "region_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.index ["creator"], name: "user_who_created_region"
    t.index ["retired"], name: "retired_status"
    t.index ["retired_by"], name: "user_who_retired_region"
  end

  create_table "regions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "relationship", primary_key: "relationship_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "person_a", null: false
    t.integer "relationship", default: 0, null: false
    t.integer "person_b", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38
    t.index ["creator"], name: "relation_creator"
    t.index ["person_a"], name: "related_person"
    t.index ["person_b"], name: "related_relative"
    t.index ["relationship"], name: "relationship_type"
    t.index ["uuid"], name: "relationship_uuid_index", unique: true
    t.index ["voided_by"], name: "relation_voider"
  end

  create_table "relationship_type", primary_key: "relationship_type_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "a_is_to_b", limit: 50, null: false
    t.string "b_is_to_a", limit: 50, null: false
    t.integer "preferred", default: 0, null: false
    t.integer "weight", default: 0, null: false
    t.string "description", default: "", null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.string "uuid", limit: 38, null: false
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.index ["creator"], name: "user_who_created_rel"
    t.index ["retired_by"], name: "user_who_retired_relationship_type"
    t.index ["uuid"], name: "relationship_type_uuid_index", unique: true
  end

  create_table "report_def", primary_key: "report_def_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "name", limit: 16777215, null: false
    t.datetime "date_created", null: false
    t.integer "creator", default: 0, null: false
    t.index ["creator"], name: "User who created report_def"
  end

  create_table "report_object", primary_key: "report_object_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "description", limit: 1000
    t.string "report_object_type", null: false
    t.string "report_object_sub_type", null: false
    t.text "xml_data"
    t.integer "creator", null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "voided", limit: 2, default: 0, null: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "user_who_changed_report_object"
    t.index ["creator"], name: "report_object_creator"
    t.index ["uuid"], name: "report_object_uuid_index", unique: true
    t.index ["voided_by"], name: "user_who_voided_report_object"
  end

  create_table "report_schema_xml", primary_key: "report_schema_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.text "xml_data", limit: 16777215, null: false
    t.string "uuid", limit: 38, null: false
    t.index ["uuid"], name: "report_schema_xml_uuid_index", unique: true
  end

  create_table "reporting_report_design", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "uuid", limit: 38, null: false
    t.string "name", null: false
    t.string "description", limit: 1000
    t.integer "report_definition_id", default: 0, null: false
    t.string "renderer_type", null: false
    t.text "properties"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.index ["changed_by"], name: "changed_by for reporting_report_design"
    t.index ["creator"], name: "creator for reporting_report_design"
    t.index ["report_definition_id"], name: "report_definition_id for reporting_report_design"
    t.index ["retired_by"], name: "retired_by for reporting_report_design"
  end

  create_table "reporting_report_design_resource", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "uuid", limit: 38, null: false
    t.string "name", null: false
    t.string "description", limit: 1000
    t.integer "report_design_id", default: 0, null: false
    t.string "content_type", limit: 50
    t.string "extension", limit: 20
    t.binary "contents", limit: 4294967295
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.index ["changed_by"], name: "changed_by for reporting_report_design_resource"
    t.index ["creator"], name: "creator for reporting_report_design_resource"
    t.index ["report_design_id"], name: "report_design_id for reporting_report_design_resource"
    t.index ["retired_by"], name: "retired_by for reporting_report_design_resource"
  end

  create_table "role", primary_key: "role", id: :string, limit: 50, default: "", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "description", default: "", null: false
    t.string "uuid", limit: 38, null: false
    t.index ["uuid"], name: "role_uuid_index", unique: true
  end

  create_table "role_privilege", primary_key: ["privilege", "role"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "role", limit: 50, default: "", null: false
    t.string "privilege", limit: 50, default: "", null: false
    t.index ["role"], name: "role_privilege"
  end

  create_table "role_role", primary_key: ["parent_role", "child_role"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "parent_role", limit: 50, default: "", null: false
    t.string "child_role", default: "", null: false
    t.index ["child_role"], name: "inherited_role"
  end

  create_table "scheduler_task_config", primary_key: "task_config_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "description", limit: 1024
    t.text "schedulable_class"
    t.datetime "start_time"
    t.string "start_time_pattern", limit: 50
    t.integer "repeat_interval", default: 0, null: false
    t.integer "start_on_startup", default: 0, null: false
    t.integer "started", default: 0, null: false
    t.integer "created_by", default: 0
    t.datetime "date_created", default: "2005-01-01 00:00:00"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "uuid", limit: 38, null: false
    t.datetime "last_execution_time"
    t.index ["changed_by"], name: "schedule_changer"
    t.index ["created_by"], name: "schedule_creator"
    t.index ["uuid"], name: "scheduler_task_config_uuid_index", unique: true
  end

  create_table "scheduler_task_config_property", primary_key: "task_config_property_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", null: false
    t.text "value"
    t.integer "task_config_id"
    t.index ["task_config_id"], name: "task_config"
  end

  create_table "serialized_object", primary_key: "serialized_object_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "name", null: false
    t.string "description", limit: 5000
    t.string "type", null: false
    t.string "subtype", null: false
    t.string "serialization_class", null: false
    t.text "serialized_data", null: false
    t.datetime "date_created", null: false
    t.integer "creator", null: false
    t.datetime "date_changed"
    t.integer "changed_by"
    t.integer "retired", limit: 2, default: 0, null: false
    t.datetime "date_retired"
    t.integer "retired_by"
    t.string "retire_reason", limit: 1000
    t.string "uuid", limit: 38, null: false
    t.index ["changed_by"], name: "serialized_object_changed_by"
    t.index ["creator"], name: "serialized_object_creator"
    t.index ["retired_by"], name: "serialized_object_retired_by"
    t.index ["uuid"], name: "serialized_object_uuid_index", unique: true
  end

  create_table "sessions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "session_id"
    t.text "data", limit: 4294967295
    t.datetime "updated_at"
    t.index ["session_id"], name: "sessions_session_id_index"
  end

  create_table "task", primary_key: "task_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "url"
    t.string "encounter_type"
    t.text "description"
    t.string "location"
    t.string "gender", limit: 50
    t.integer "has_obs_concept_id"
    t.integer "has_obs_value_coded"
    t.integer "has_obs_value_drug"
    t.datetime "has_obs_value_datetime"
    t.float "has_obs_value_numeric", limit: 53
    t.text "has_obs_value_text"
    t.text "has_obs_scope"
    t.integer "has_program_id"
    t.integer "has_program_workflow_state_id"
    t.integer "has_identifier_type_id"
    t.integer "has_relationship_type_id"
    t.integer "has_order_type_id"
    t.string "has_encounter_type_today"
    t.integer "skip_if_has", limit: 2, default: 0
    t.float "sort_weight", limit: 53
    t.integer "creator", null: false
    t.datetime "date_created", null: false
    t.integer "voided", limit: 2, default: 0
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "uuid", limit: 38
    t.index ["changed_by"], name: "user_who_changed_task"
    t.index ["creator"], name: "task_creator"
    t.index ["voided_by"], name: "user_who_voided_task"
  end

  create_table "traditional_authorities", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "traditional_authority", primary_key: "traditional_authority_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.integer "district_id", default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.index ["creator"], name: "user_who_created_traditional_authority"
    t.index ["district_id"], name: "district_for_ta"
    t.index ["retired"], name: "retired_status"
    t.index ["retired_by"], name: "user_who_retired_traditional_authority"
  end

  create_table "tribe", primary_key: "tribe_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.boolean "retired", default: false, null: false
    t.string "name", limit: 50, default: "", null: false
  end

  create_table "user_activation", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "system_id", limit: 45, null: false
    t.string "status", limit: 45, null: false
    t.index ["id"], name: "id_UNIQUE", unique: true
  end

  create_table "user_property", primary_key: ["user_id", "property"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.string "property", limit: 100, default: "", null: false
    t.string "property_value", limit: 600, default: "", null: false
  end

  create_table "user_role", primary_key: ["role", "user_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.string "role", limit: 50, default: "", null: false
    t.index ["user_id"], name: "user_role"
  end

  create_table "users", primary_key: "user_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "system_id", limit: 50, default: "", null: false
    t.string "username", limit: 50
    t.string "password", limit: 128
    t.string "salt", limit: 128
    t.string "secret_question"
    t.string "secret_answer"
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.integer "changed_by"
    t.datetime "date_changed"
    t.integer "person_id"
    t.integer "retired", limit: 1, default: 0, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid", limit: 38, null: false
    t.string "authentication_token"
    t.index ["changed_by"], name: "user_who_changed_user"
    t.index ["creator"], name: "user_creator"
    t.index ["person_id"], name: "person_id_for_user"
    t.index ["retired_by"], name: "user_who_retired_this_user"
  end

  create_table "validation_results", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "rule_id"
    t.integer "failures"
    t.date "date_checked"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "validation_rules", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "expr"
    t.text "desc"
    t.integer "type_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "village", primary_key: "village_id", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.integer "traditional_authority_id", default: 0, null: false
    t.integer "creator", default: 0, null: false
    t.datetime "date_created", null: false
    t.boolean "retired", default: false, null: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.index ["creator"], name: "user_who_created_village"
    t.index ["retired"], name: "retired_status"
    t.index ["retired_by"], name: "user_who_retired_village"
    t.index ["traditional_authority_id"], name: "ta_for_village"
  end

  create_table "villages", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "weight_for_height", id: false, options: "ENGINE=MyISAM DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.float "supinecm", limit: 53
    t.float "medianwtht", limit: 53
    t.float "sdlowwtht", limit: 53
    t.float "sdhighwtht", limit: 53
    t.integer "sex", limit: 2
    t.string "heightsex", limit: 5
  end

  create_table "weight_for_heights", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.float "supine_cm"
    t.float "median_weight_height"
    t.float "standard_low_weight_height"
    t.float "standard_high_weight_height"
    t.integer "sex"
  end

  create_table "weight_height_for_age", id: false, options: "ENGINE=MyISAM DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "agemths", limit: 2
    t.integer "sex", limit: 2
    t.float "medianht", limit: 53
    t.float "sdlowht", limit: 53
    t.float "sdhighht", limit: 53
    t.float "medianwt", limit: 53
    t.float "sdlowwt", limit: 53
    t.float "sdhighwt", limit: 53
    t.string "agesex", limit: 4
  end

  create_table "weight_height_for_ages", id: false, options: "ENGINE=MyISAM DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "age_in_months", limit: 2
    t.string "sex", limit: 12
    t.float "median_height", limit: 53
    t.float "standard_low_height", limit: 53
    t.float "standard_high_height", limit: 53
    t.float "median_weight", limit: 53
    t.float "standard_low_weight", limit: 53
    t.float "standard_high_weight", limit: 53
    t.string "age_sex", limit: 4
    t.index ["age_in_months"], name: "index_weight_height_for_ages_on_age_in_months"
    t.index ["sex"], name: "index_weight_height_for_ages_on_sex"
  end

  add_foreign_key "active_list", "active_list_type", primary_key: "active_list_type_id", name: "active_list_type_of_active_list"
  add_foreign_key "active_list", "concept", primary_key: "concept_id", name: "concept_active_list"
  add_foreign_key "active_list", "obs", column: "start_obs_id", primary_key: "obs_id", name: "start_obs_active_list"
  add_foreign_key "active_list", "obs", column: "stop_obs_id", primary_key: "obs_id", name: "stop_obs_active_list"
  add_foreign_key "active_list", "person", primary_key: "person_id", name: "person_of_active_list"
  add_foreign_key "active_list", "users", column: "creator", primary_key: "user_id", name: "user_who_created_active_list"
  add_foreign_key "active_list", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_active_list"
  add_foreign_key "active_list_allergy", "concept", column: "reaction_concept_id", primary_key: "concept_id", name: "reaction_allergy"
  add_foreign_key "active_list_type", "users", column: "creator", primary_key: "user_id", name: "user_who_created_active_list_type"
  add_foreign_key "active_list_type", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_active_list_type"
  add_foreign_key "cohort", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_cohort"
  add_foreign_key "cohort", "users", column: "creator", primary_key: "user_id", name: "cohort_creator"
  add_foreign_key "cohort", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_cohort"
  add_foreign_key "cohort_member", "cohort", primary_key: "cohort_id", name: "parent_cohort"
  add_foreign_key "cohort_member", "patient", primary_key: "patient_id", name: "member_patient", on_update: :cascade
  add_foreign_key "complex_obs", "mime_type", primary_key: "mime_type_id", name: "complex_obs_ibfk_1"
  add_foreign_key "complex_obs", "obs", column: "obs_id", primary_key: "obs_id", name: "obs_pointing_to_complex_content"
  add_foreign_key "concept", "concept_class", column: "class_id", primary_key: "concept_class_id", name: "concept_classes"
  add_foreign_key "concept", "concept_datatype", column: "datatype_id", primary_key: "concept_datatype_id", name: "concept_datatypes"
  add_foreign_key "concept", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_concept"
  add_foreign_key "concept", "users", column: "creator", primary_key: "user_id", name: "concept_creator"
  add_foreign_key "concept", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_concept"
  add_foreign_key "concept_answer", "concept", column: "answer_concept", primary_key: "concept_id", name: "answer"
  add_foreign_key "concept_answer", "concept", primary_key: "concept_id", name: "answers_for_concept"
  add_foreign_key "concept_answer", "users", column: "creator", primary_key: "user_id", name: "answer_creator"
  add_foreign_key "concept_class", "users", column: "creator", primary_key: "user_id", name: "concept_class_creator"
  add_foreign_key "concept_class", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_concept_class"
  add_foreign_key "concept_complex", "concept", primary_key: "concept_id", name: "concept_attributes"
  add_foreign_key "concept_datatype", "users", column: "creator", primary_key: "user_id", name: "concept_datatype_creator"
  add_foreign_key "concept_datatype", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_concept_datatype"
  add_foreign_key "concept_derived", "concept", primary_key: "concept_id", name: "derived_attributes"
  add_foreign_key "concept_description", "concept", primary_key: "concept_id", name: "description_for_concept"
  add_foreign_key "concept_description", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_description"
  add_foreign_key "concept_description", "users", column: "creator", primary_key: "user_id", name: "user_who_created_description"
  add_foreign_key "concept_map", "concept", primary_key: "concept_id", name: "map_for_concept"
  add_foreign_key "concept_map", "concept_source", column: "source", primary_key: "concept_source_id", name: "map_source"
  add_foreign_key "concept_map", "users", column: "creator", primary_key: "user_id", name: "map_creator"
  add_foreign_key "concept_name", "concept", primary_key: "concept_id", name: "name_for_concept"
  add_foreign_key "concept_name", "users", column: "creator", primary_key: "user_id", name: "user_who_created_name"
  add_foreign_key "concept_name", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_this_name"
  add_foreign_key "concept_name_tag_map", "concept_name", primary_key: "concept_name_id", name: "mapped_concept_name"
  add_foreign_key "concept_name_tag_map", "concept_name_tag", primary_key: "concept_name_tag_id", name: "mapped_concept_name_tag"
  add_foreign_key "concept_numeric", "concept", primary_key: "concept_id", name: "numeric_attributes"
  add_foreign_key "concept_proposal", "concept", column: "obs_concept_id", primary_key: "concept_id", name: "proposal_obs_concept_id"
  add_foreign_key "concept_proposal", "concept", primary_key: "concept_id", name: "concept_for_proposal"
  add_foreign_key "concept_proposal", "encounter", primary_key: "encounter_id", name: "encounter_for_proposal"
  add_foreign_key "concept_proposal", "obs", column: "obs_id", primary_key: "obs_id", name: "proposal_obs_id"
  add_foreign_key "concept_proposal", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_proposal"
  add_foreign_key "concept_proposal", "users", column: "creator", primary_key: "user_id", name: "user_who_created_proposal"
  add_foreign_key "concept_proposal_tag_map", "concept_name_tag", primary_key: "concept_name_tag_id", name: "mapped_concept_proposal_tag"
  add_foreign_key "concept_proposal_tag_map", "concept_proposal", primary_key: "concept_proposal_id", name: "mapped_concept_proposal"
  add_foreign_key "concept_set", "concept", column: "concept_set", primary_key: "concept_id", name: "has_a"
  add_foreign_key "concept_set", "concept", primary_key: "concept_id", name: "is_a"
  add_foreign_key "concept_set", "users", column: "creator", primary_key: "user_id", name: "user_who_created"
  add_foreign_key "concept_source", "users", column: "creator", primary_key: "user_id", name: "concept_source_creator"
  add_foreign_key "concept_source", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_concept_source"
  add_foreign_key "concept_state_conversion", "concept", primary_key: "concept_id", name: "concept_triggers_conversion"
  add_foreign_key "concept_state_conversion", "program_workflow", primary_key: "program_workflow_id", name: "conversion_involves_workflow"
  add_foreign_key "concept_state_conversion", "program_workflow_state", primary_key: "program_workflow_state_id", name: "conversion_to_state"
  add_foreign_key "concept_synonym", "concept", primary_key: "concept_id", name: "synonym_for"
  add_foreign_key "concept_synonym", "users", column: "creator", primary_key: "user_id", name: "synonym_creator"
  add_foreign_key "concept_word", "concept", primary_key: "concept_id", name: "word_for"
  add_foreign_key "concept_word", "concept_name", primary_key: "concept_name_id", name: "word_for_name"
  add_foreign_key "district", "region", primary_key: "region_id", name: "region_for_district"
  add_foreign_key "district", "users", column: "creator", primary_key: "user_id", name: "user_who_created_district"
  add_foreign_key "district", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_district"
  add_foreign_key "drug", "concept", column: "dosage_form", primary_key: "concept_id", name: "dosage_form_concept"
  add_foreign_key "drug", "concept", column: "route", primary_key: "concept_id", name: "route_concept"
  add_foreign_key "drug", "concept", primary_key: "concept_id", name: "primary_drug_concept"
  add_foreign_key "drug", "users", column: "creator", primary_key: "user_id", name: "drug_creator"
  add_foreign_key "drug", "users", column: "retired_by", primary_key: "user_id", name: "drug_retired_by"
  add_foreign_key "drug_ingredient", "concept", column: "ingredient_id", primary_key: "concept_id", name: "ingredient"
  add_foreign_key "drug_ingredient", "concept", primary_key: "concept_id", name: "combination_drug"
  add_foreign_key "drug_order", "drug", column: "drug_inventory_id", primary_key: "drug_id", name: "inventory_item"
  add_foreign_key "drug_order", "orders", primary_key: "order_id", name: "extends_order"
  add_foreign_key "encounter", "encounter_type", column: "encounter_type", primary_key: "encounter_type_id", name: "encounter_type_id"
  add_foreign_key "encounter", "form", primary_key: "form_id", name: "encounter_form"
  add_foreign_key "encounter", "location", primary_key: "location_id", name: "encounter_location"
  add_foreign_key "encounter", "patient", primary_key: "patient_id", name: "encounter_patient", on_update: :cascade
  add_foreign_key "encounter", "person", column: "provider_id", primary_key: "person_id", name: "encounter_provider"
  add_foreign_key "encounter", "users", column: "changed_by", primary_key: "user_id", name: "encounter_changed_by"
  add_foreign_key "encounter", "users", column: "creator", primary_key: "user_id", name: "encounter_ibfk_1"
  add_foreign_key "encounter", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_encounter"
  add_foreign_key "encounter_type", "users", column: "creator", primary_key: "user_id", name: "user_who_created_type"
  add_foreign_key "encounter_type", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_encounter_type"
  add_foreign_key "external_source", "concept_source", column: "source", primary_key: "concept_source_id", name: "map_ext_source"
  add_foreign_key "external_source", "users", column: "creator", primary_key: "user_id", name: "map_ext_creator"
  add_foreign_key "field", "concept", primary_key: "concept_id", name: "concept_for_field"
  add_foreign_key "field", "field_type", column: "field_type", primary_key: "field_type_id", name: "type_of_field"
  add_foreign_key "field", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_field"
  add_foreign_key "field", "users", column: "creator", primary_key: "user_id", name: "user_who_created_field"
  add_foreign_key "field", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_field"
  add_foreign_key "field_answer", "concept", column: "answer_id", primary_key: "concept_id", name: "field_answer_concept"
  add_foreign_key "field_answer", "field", primary_key: "field_id", name: "answers_for_field"
  add_foreign_key "field_answer", "users", column: "creator", primary_key: "user_id", name: "user_who_created_field_answer"
  add_foreign_key "field_type", "users", column: "creator", primary_key: "user_id", name: "user_who_created_field_type"
  add_foreign_key "form", "encounter_type", column: "encounter_type", primary_key: "encounter_type_id", name: "form_encounter_type"
  add_foreign_key "form", "users", column: "changed_by", primary_key: "user_id", name: "user_who_last_changed_form"
  add_foreign_key "form", "users", column: "creator", primary_key: "user_id", name: "user_who_created_form"
  add_foreign_key "form", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_form"
  add_foreign_key "form2program_map", "encounter_type", column: "encounter_type", primary_key: "encounter_type_id", name: "form2program_map_ibfk_2"
  add_foreign_key "form2program_map", "program", column: "program", primary_key: "program_id", name: "form2program_map_ibfk_1"
  add_foreign_key "form2program_map", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_form2program"
  add_foreign_key "form2program_map", "users", column: "creator", primary_key: "user_id", name: "user_who_created_form2program"
  add_foreign_key "form_field", "field", primary_key: "field_id", name: "field_within_form"
  add_foreign_key "form_field", "form", primary_key: "form_id", name: "form_containing_field"
  add_foreign_key "form_field", "form_field", column: "parent_form_field", primary_key: "form_field_id", name: "form_field_hierarchy"
  add_foreign_key "form_field", "users", column: "changed_by", primary_key: "user_id", name: "user_who_last_changed_form_field"
  add_foreign_key "form_field", "users", column: "creator", primary_key: "user_id", name: "user_who_created_form_field"
  add_foreign_key "formentry_archive", "users", column: "creator", primary_key: "user_id", name: "User who created formentry_archive"
  add_foreign_key "formentry_error", "users", column: "creator", primary_key: "user_id", name: "User who created formentry_error"
  add_foreign_key "formentry_xsn", "form", primary_key: "form_id", name: "Form with which this xsn is related"
  add_foreign_key "formentry_xsn", "users", column: "archived_by", primary_key: "user_id", name: "User who archived formentry_xsn"
  add_foreign_key "formentry_xsn", "users", column: "creator", primary_key: "user_id", name: "User who created formentry_xsn"
  add_foreign_key "hl7_in_queue", "hl7_source", column: "hl7_source", primary_key: "hl7_source_id", name: "hl7_source"
  add_foreign_key "hl7_source", "users", column: "creator", primary_key: "user_id", name: "creator"
  add_foreign_key "htmlformentry_html_form", "form", primary_key: "form_id", name: "Form with which this htmlform is related"
  add_foreign_key "htmlformentry_html_form", "users", column: "changed_by", primary_key: "user_id", name: "User who changed htmlformentry_htmlform"
  add_foreign_key "htmlformentry_html_form", "users", column: "creator", primary_key: "user_id", name: "User who created htmlformentry_htmlform"
  add_foreign_key "location", "location", column: "parent_location", primary_key: "location_id", name: "parent_location"
 # add_foreign_key "location", "location_type", primary_key: "location_type_id", name: "location_type"
  add_foreign_key "location", "users", column: "creator", primary_key: "user_id", name: "user_who_created_location"
  add_foreign_key "location", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_location"
  add_foreign_key "location_tag", "users", column: "creator", primary_key: "user_id", name: "location_tag_creator"
  add_foreign_key "location_tag", "users", column: "retired_by", primary_key: "user_id", name: "location_tag_retired_by"
  add_foreign_key "location_tag_map", "location", primary_key: "location_id", name: "location_tag_map_location"
  add_foreign_key "location_tag_map", "location_tag", primary_key: "location_tag_id", name: "location_tag_map_tag"
  add_foreign_key "logic_rule_definition", "users", column: "changed_by", primary_key: "user_id", name: "changed_by for rule_definition"
  add_foreign_key "logic_rule_definition", "users", column: "creator", primary_key: "user_id", name: "creator for rule_definition"
  add_foreign_key "logic_rule_definition", "users", column: "retired_by", primary_key: "user_id", name: "retired_by for rule_definition"
  add_foreign_key "logic_rule_token", "person", column: "changed_by", primary_key: "person_id", name: "token_changed_by"
  add_foreign_key "logic_rule_token", "person", column: "creator", primary_key: "person_id", name: "token_creator"
  add_foreign_key "logic_rule_token_tag", "logic_rule_token", primary_key: "logic_rule_token_id", name: "token_tag"
  add_foreign_key "logic_token_registration", "users", column: "changed_by", primary_key: "user_id", name: "token_registration_changed_by"
  add_foreign_key "logic_token_registration", "users", column: "creator", primary_key: "user_id", name: "token_registration_creator"
  add_foreign_key "logic_token_registration_tag", "logic_token_registration", column: "token_registration_id", primary_key: "token_registration_id", name: "token_registration_tag"
  add_foreign_key "note", "encounter", primary_key: "encounter_id", name: "encounter_note"
  add_foreign_key "note", "note", column: "parent", primary_key: "note_id", name: "note_hierarchy"
  add_foreign_key "note", "obs", column: "obs_id", primary_key: "obs_id", name: "obs_note"
  add_foreign_key "note", "patient", primary_key: "patient_id", name: "patient_note", on_update: :cascade
  add_foreign_key "note", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_note"
  add_foreign_key "note", "users", column: "creator", primary_key: "user_id", name: "user_who_created_note"
  add_foreign_key "notification_alert", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_alert"
  add_foreign_key "notification_alert", "users", column: "creator", primary_key: "user_id", name: "alert_creator"
  add_foreign_key "notification_alert_recipient", "notification_alert", column: "alert_id", primary_key: "alert_id", name: "id_of_alert"
  add_foreign_key "notification_alert_recipient", "users", primary_key: "user_id", name: "alert_read_by_user"
  add_foreign_key "obs", "concept", column: "value_coded", primary_key: "concept_id", name: "answer_concept"
  add_foreign_key "obs", "concept", primary_key: "concept_id", name: "obs_concept"
  add_foreign_key "obs", "concept_name", column: "value_coded_name_id", primary_key: "concept_name_id", name: "obs_name_of_coded_value"
  add_foreign_key "obs", "drug", column: "value_drug", primary_key: "drug_id", name: "answer_concept_drug"
  add_foreign_key "obs", "encounter", primary_key: "encounter_id", name: "encounter_observations"
  add_foreign_key "obs", "location", primary_key: "location_id", name: "obs_location"
  add_foreign_key "obs", "obs", column: "obs_group_id", primary_key: "obs_id", name: "obs_grouping_id"
  add_foreign_key "obs", "orders", primary_key: "order_id", name: "obs_order"
  add_foreign_key "obs", "person", primary_key: "person_id", name: "person_obs", on_update: :cascade
  add_foreign_key "obs", "users", column: "creator", primary_key: "user_id", name: "obs_enterer"
  add_foreign_key "obs", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_obs"
  add_foreign_key "order_extension", "users", column: "creator", primary_key: "user_id", name: "user_who_created_extension"
  add_foreign_key "order_extension", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_extension"
  add_foreign_key "order_type", "users", column: "creator", primary_key: "user_id", name: "type_created_by"
  add_foreign_key "order_type", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_order_type"
  add_foreign_key "orders", "concept", column: "discontinued_reason", primary_key: "concept_id", name: "discontinued_because"
  add_foreign_key "orders", "encounter", primary_key: "encounter_id", name: "orders_in_encounter"
  add_foreign_key "orders", "obs", column: "obs_id", primary_key: "obs_id", name: "obs_for_order"
  add_foreign_key "orders", "order_type", primary_key: "order_type_id", name: "type_of_order"
  add_foreign_key "orders", "patient", primary_key: "patient_id", name: "order_for_patient", on_update: :cascade
  add_foreign_key "orders", "users", column: "creator", primary_key: "user_id", name: "order_creator"
  add_foreign_key "orders", "users", column: "discontinued_by", primary_key: "user_id", name: "user_who_discontinued_order"
  add_foreign_key "orders", "users", column: "orderer", primary_key: "user_id", name: "orderer_not_drug"
  add_foreign_key "orders", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_order"
  add_foreign_key "patient", "person", column: "patient_id", primary_key: "person_id", name: "person_id_for_patient", on_update: :cascade
  add_foreign_key "patient", "tribe", column: "tribe", primary_key: "tribe_id", name: "belongs_to_tribe"
  add_foreign_key "patient", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_pat"
  add_foreign_key "patient", "users", column: "creator", primary_key: "user_id", name: "user_who_created_patient"
  add_foreign_key "patient", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_patient"
  add_foreign_key "patient_identifier", "location", primary_key: "location_id", name: "patient_identifier_ibfk_2"
  add_foreign_key "patient_identifier", "patient", primary_key: "patient_id", name: "identifies_patient"
  add_foreign_key "patient_identifier", "patient_identifier_type", column: "identifier_type", primary_key: "patient_identifier_type_id", name: "defines_identifier_type"
  add_foreign_key "patient_identifier", "users", column: "creator", primary_key: "user_id", name: "identifier_creator"
  add_foreign_key "patient_identifier", "users", column: "voided_by", primary_key: "user_id", name: "identifier_voider"
  add_foreign_key "patient_identifier_type", "users", column: "creator", primary_key: "user_id", name: "type_creator"
  add_foreign_key "patient_identifier_type", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_patient_identifier_type"
  add_foreign_key "patient_program", "patient", primary_key: "patient_id", name: "patient_in_program", on_update: :cascade
  add_foreign_key "patient_program", "program", primary_key: "program_id", name: "program_for_patient"
  add_foreign_key "patient_program", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed"
  add_foreign_key "patient_program", "users", column: "creator", primary_key: "user_id", name: "patient_program_creator"
  add_foreign_key "patient_program", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_patient_program"
  add_foreign_key "patient_state", "patient_program", primary_key: "patient_program_id", name: "patient_program_for_state"
  add_foreign_key "patient_state", "program_workflow_state", column: "state", primary_key: "program_workflow_state_id", name: "state_for_patient"
  add_foreign_key "patient_state", "users", column: "changed_by", primary_key: "user_id", name: "patient_state_changer"
  add_foreign_key "patient_state", "users", column: "creator", primary_key: "user_id", name: "patient_state_creator"
  add_foreign_key "patient_state", "users", column: "voided_by", primary_key: "user_id", name: "patient_state_voider"
  add_foreign_key "patientflags_flag_tag", "patientflags_flag", column: "flag_id", primary_key: "flag_id", name: "patientflags_flag_tag_ibfk_1"
  add_foreign_key "patientflags_flag_tag", "patientflags_tag", column: "tag_id", primary_key: "tag_id", name: "patientflags_flag_tag_ibfk_2"
  add_foreign_key "person", "concept", column: "cause_of_death", primary_key: "concept_id", name: "person_died_because"
  add_foreign_key "person", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_person"
  add_foreign_key "person", "users", column: "creator", primary_key: "user_id", name: "user_who_created_person"
  add_foreign_key "person", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_person"
  add_foreign_key "person_address", "person", primary_key: "person_id", name: "address_for_person", on_update: :cascade
  add_foreign_key "person_address", "users", column: "creator", primary_key: "user_id", name: "patient_address_creator"
  add_foreign_key "person_address", "users", column: "voided_by", primary_key: "user_id", name: "patient_address_void"
  add_foreign_key "person_attribute", "person", primary_key: "person_id", name: "identifies_person"
  add_foreign_key "person_attribute", "person_attribute_type", primary_key: "person_attribute_type_id", name: "defines_attribute_type"
  add_foreign_key "person_attribute", "users", column: "changed_by", primary_key: "user_id", name: "attribute_changer"
  add_foreign_key "person_attribute", "users", column: "creator", primary_key: "user_id", name: "attribute_creator"
  add_foreign_key "person_attribute", "users", column: "voided_by", primary_key: "user_id", name: "attribute_voider"
  add_foreign_key "person_attribute_type", "privilege", column: "edit_privilege", primary_key: "privilege", name: "privilege_which_can_edit"
  add_foreign_key "person_attribute_type", "users", column: "changed_by", primary_key: "user_id", name: "attribute_type_changer"
  add_foreign_key "person_attribute_type", "users", column: "creator", primary_key: "user_id", name: "attribute_type_creator"
  add_foreign_key "person_attribute_type", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_person_attribute_type"
  add_foreign_key "person_name", "person", primary_key: "person_id", name: "name for person", on_update: :cascade
  add_foreign_key "person_name", "users", column: "creator", primary_key: "user_id", name: "user_who_made_name"
  add_foreign_key "person_name", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_name"
  add_foreign_key "person_name_code", "person_name", primary_key: "person_name_id", name: "code for name", on_update: :cascade
  add_foreign_key "program", "concept", primary_key: "concept_id", name: "program_concept"
  add_foreign_key "program", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_program"
  add_foreign_key "program", "users", column: "creator", primary_key: "user_id", name: "program_creator"
  add_foreign_key "program_encounter_type_map", "encounter_type", primary_key: "encounter_type_id", name: "referenced_encounter_type"
  add_foreign_key "program_encounter_type_map", "program", primary_key: "program_id", name: "referenced_program_encounter_type_map"
  add_foreign_key "program_location_restriction", "location", primary_key: "location_id", name: "referenced_location"
  add_foreign_key "program_location_restriction", "program", primary_key: "program_id", name: "referenced_program"
  add_foreign_key "program_orders_map", "concept", primary_key: "concept_id", name: "referenced_concept_id"
  add_foreign_key "program_orders_map", "program", primary_key: "program_id", name: "referenced_program_orders_type_map"
  add_foreign_key "program_patient_identifier_type_map", "patient_identifier_type", primary_key: "patient_identifier_type_id", name: "referenced_patient_identifier_type"
  add_foreign_key "program_patient_identifier_type_map", "program", primary_key: "program_id", name: "referenced_program_patient_identifier_type_map"
  add_foreign_key "program_relationship_type_map", "program", primary_key: "program_id", name: "referenced_program_relationship_type_map"
  add_foreign_key "program_relationship_type_map", "relationship_type", primary_key: "relationship_type_id", name: "referenced_relationship_type"
  add_foreign_key "program_workflow", "concept", primary_key: "concept_id", name: "workflow_concept"
  add_foreign_key "program_workflow", "program", primary_key: "program_id", name: "program_for_workflow"
  add_foreign_key "program_workflow", "users", column: "changed_by", primary_key: "user_id", name: "workflow_changed_by"
  add_foreign_key "program_workflow", "users", column: "creator", primary_key: "user_id", name: "workflow_creator"
  add_foreign_key "program_workflow_state", "concept", primary_key: "concept_id", name: "state_concept"
  add_foreign_key "program_workflow_state", "program_workflow", primary_key: "program_workflow_id", name: "workflow_for_state"
  add_foreign_key "program_workflow_state", "users", column: "changed_by", primary_key: "user_id", name: "state_changed_by"
  add_foreign_key "program_workflow_state", "users", column: "creator", primary_key: "user_id", name: "state_creator"
  add_foreign_key "regimen", "concept", primary_key: "concept_id", name: "map_concept"
  add_foreign_key "regimen_drug_order", "drug", column: "drug_inventory_id", primary_key: "drug_id", name: "map_drug_inventory"
  add_foreign_key "regimen_drug_order", "regimen", column: "regimen_id", primary_key: "regimen_id", name: "map_regimen"
  add_foreign_key "regimen_drug_order", "users", column: "creator", primary_key: "user_id", name: "regimen_drug_order_creator"
  add_foreign_key "regimen_drug_order", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_regimen_drug_order"
  add_foreign_key "region", "users", column: "creator", primary_key: "user_id", name: "user_who_created_region"
  add_foreign_key "region", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_region"
  add_foreign_key "relationship", "person", column: "person_a", primary_key: "person_id", name: "person_a", on_update: :cascade
  add_foreign_key "relationship", "person", column: "person_b", primary_key: "person_id", name: "person_b", on_update: :cascade
  add_foreign_key "relationship", "relationship_type", column: "relationship", primary_key: "relationship_type_id", name: "relationship_type_id"
  add_foreign_key "relationship", "users", column: "creator", primary_key: "user_id", name: "relation_creator"
  add_foreign_key "relationship", "users", column: "voided_by", primary_key: "user_id", name: "relation_voider"
  add_foreign_key "relationship_type", "users", column: "creator", primary_key: "user_id", name: "user_who_created_rel"
  add_foreign_key "relationship_type", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_relationship_type"
  add_foreign_key "report_def", "users", column: "creator", primary_key: "user_id", name: "User who created report_def"
  add_foreign_key "report_object", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_report_object"
  add_foreign_key "report_object", "users", column: "creator", primary_key: "user_id", name: "report_object_creator"
  add_foreign_key "report_object", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_report_object"
  add_foreign_key "reporting_report_design", "serialized_object", column: "report_definition_id", primary_key: "serialized_object_id", name: "report_definition_id for reporting_report_design"
  add_foreign_key "reporting_report_design", "users", column: "changed_by", primary_key: "user_id", name: "changed_by for reporting_report_design"
  add_foreign_key "reporting_report_design", "users", column: "creator", primary_key: "user_id", name: "creator for reporting_report_design"
  add_foreign_key "reporting_report_design", "users", column: "retired_by", primary_key: "user_id", name: "retired_by for reporting_report_design"
  add_foreign_key "reporting_report_design_resource", "reporting_report_design", column: "report_design_id", name: "report_design_id for reporting_report_design_resource"
  add_foreign_key "reporting_report_design_resource", "users", column: "changed_by", primary_key: "user_id", name: "changed_by for reporting_report_design_resource"
  add_foreign_key "reporting_report_design_resource", "users", column: "creator", primary_key: "user_id", name: "creator for reporting_report_design_resource"
  add_foreign_key "reporting_report_design_resource", "users", column: "retired_by", primary_key: "user_id", name: "retired_by for reporting_report_design_resource"
  add_foreign_key "role_privilege", "privilege", column: "privilege", primary_key: "privilege", name: "privilege_definitons"
  add_foreign_key "role_privilege", "role", column: "role", primary_key: "role", name: "role_privilege"
  add_foreign_key "role_role", "role", column: "child_role", primary_key: "role", name: "inherited_role"
  add_foreign_key "role_role", "role", column: "parent_role", primary_key: "role", name: "parent_role"
  add_foreign_key "scheduler_task_config", "users", column: "changed_by", primary_key: "user_id", name: "scheduler_changer"
  add_foreign_key "scheduler_task_config", "users", column: "created_by", primary_key: "user_id", name: "scheduler_creator"
  add_foreign_key "scheduler_task_config_property", "scheduler_task_config", column: "task_config_id", primary_key: "task_config_id", name: "task_config_for_property"
  add_foreign_key "serialized_object", "users", column: "changed_by", primary_key: "user_id", name: "serialized_object_changed_by"
  add_foreign_key "serialized_object", "users", column: "creator", primary_key: "user_id", name: "serialized_object_creator"
  add_foreign_key "serialized_object", "users", column: "retired_by", primary_key: "user_id", name: "serialized_object_retired_by"
  add_foreign_key "task", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_task"
  add_foreign_key "task", "users", column: "creator", primary_key: "user_id", name: "task_creator"
  add_foreign_key "task", "users", column: "voided_by", primary_key: "user_id", name: "user_who_voided_task"
  add_foreign_key "traditional_authority", "district", primary_key: "district_id", name: "district_for_ta"
  add_foreign_key "traditional_authority", "users", column: "creator", primary_key: "user_id", name: "user_who_created_traditional_authority"
  add_foreign_key "traditional_authority", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_traditional_authority"
  add_foreign_key "user_property", "users", primary_key: "user_id", name: "user_property"
  add_foreign_key "user_role", "role", column: "role", primary_key: "role", name: "role_definitions"
  add_foreign_key "user_role", "users", primary_key: "user_id", name: "user_role"
  add_foreign_key "users", "person", primary_key: "person_id", name: "person_id_for_user"
  add_foreign_key "users", "users", column: "changed_by", primary_key: "user_id", name: "user_who_changed_user"
  add_foreign_key "users", "users", column: "creator", primary_key: "user_id", name: "user_creator"
  add_foreign_key "users", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_this_user"
  add_foreign_key "village", "traditional_authority", primary_key: "traditional_authority_id", name: "ta_for_village"
  add_foreign_key "village", "users", column: "creator", primary_key: "user_id", name: "user_who_created_village"
  add_foreign_key "village", "users", column: "retired_by", primary_key: "user_id", name: "user_who_retired_village"
end
