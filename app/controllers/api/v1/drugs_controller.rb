require 'securerandom'

class Api::V1::DrugsController < ApplicationController
  before_action :authenticate, except: %i[print_barcode]
  def show
    render json: Drug.find(params[:id])
  end

  def index
    filters = params.permit(%i[name concept_set])

    render json: paginate(service.find_drugs(filters))
  end

  def drug_sets
    drug_sets = {}
    set_names = {}
    set_descriptions = {}
    GeneralSet.where(["status =?", "active"]).each do |set|

      drug_sets[set.set_id] = {}
      set_names[set.set_id] = set.name
      set_descriptions[set.set_id] = set.description

      dsets = DrugSet.where(["set_id =? AND voided =?", set.set_id, 0])
      dsets.each do |d_set|

        drug_sets[set.set_id][d_set.drug_inventory_id] = {}
        drug = Drug.find(d_set.drug_inventory_id)
        drug_sets[set.set_id][d_set.drug_inventory_id]["drug_name"] = drug.name
        drug_sets[set.set_id][d_set.drug_inventory_id]["units"] = drug.units
        drug_sets[set.set_id][d_set.drug_inventory_id]["duration"] = d_set.duration
        drug_sets[set.set_id][d_set.drug_inventory_id]["frequency"] = d_set.frequency
        drug_sets[set.set_id][d_set.drug_inventory_id]["dose"] = drug.dose_strength
      end
    end
    render json: {drug_sets: drug_sets,
      set_names: set_names,
      set_descriptions: set_descriptions}
  end

  def create_drug_sets
    set_name = params[:name]
    set_desc = params[:description]
    set_drugs = params[:drugs]
    date = (params[:datetime].to_date rescue Date.today)
    results = {}

    #set_id = params[:set_id]

    unless set_name.blank?

      ActiveRecord::Base.transaction do

        set = GeneralSet.create(name: set_name,
          description: set_desc,
          status: "active",
          date_created: date,
          date_updated: date,
          creator: User.current.id
        )
        #set.save!
        set_id = set.set_id

        unless set_id.blank?

          results["set"] = {
            "name": set.name,
            "description": set.description,
            "date_created": set.date_created,
            "date_updated": set.date_updated
          }
          ( set_drugs || []).each do |drug|

            d = Drug.find_by name: drug["drug"]

            drug_set = DrugSet.create(
              drug_inventory_id: d.id,
              set_id: set_id.to_i,
              frequency: drug["frequency"],
              duration: drug["quantity"].to_i,
              date_created: date,
              date_updated: date,
              creator: User.current.id
            )

            if results["set_drugs"].blank?

              results["set_drugs"] = []

            end

            results["set_drugs"] << {drug_id: d.id, drug_name: d.name,
              frequency: drug_set.frequency, quantity: drug_set.duration}

          end

        end

      end

    end

    render json: results

  end

  def void_drug_sets
    drug_set = GeneralSet.find(params[:id])
    drug_set.deactivate params[:date].to_date # User.current, "Voided by #{User.current.username}"
  end

  def print_barcode
    quantity = params.require(:quantity)
    printer_commands = service.print_drug_barcode(drug, quantity)
    send_data(printer_commands, type: 'application/label; charset=utf-8',
                                stream: false,
                                filename: "#{SecureRandom.hex(24)}.lbl",
                                disposition: 'inline')
  end

  def tb_side_effects_drug
    render json: Drug.tb_side_effects_drug
  end

  def stock_levels
    levels = service.stock_levels(params[:classification])
    render json: levels
  end

  private

  def drug
    Drug.find(params[:drug_id])
  end

  def service
    DrugService.new
  end
end
