class Api::V1::DrugsController < ApplicationController
  def show
    render json: Drug.find(params[:id])
  end

  def index
    name = params.permit(:name)[:name]
    query = name ? Drug.where('name like ?', "#{name}%") : Drug
    render json: paginate(query)
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

end
