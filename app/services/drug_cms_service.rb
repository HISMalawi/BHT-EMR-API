class DrugCmsService

  #get all drugs
  def get_all_drug_cms
    DrugCms.all
  end

  #get specific drug using id
  def get_drug_cms(params)
    DrugCms.find(params[:id])
  end

  #create drug_cms
  def create_drug_cms(params)
    new_drug_cms_params = params.permit(:code, :drug_inventory_id, :name, :short_name,
      :tabs, :pack_size, :weight, :strength, :voided, :voided_by, :date_voided, :void_reason)
    found_drug_cms = DrugCms.where("(code IN(?) OR name IN (?) OR short_name IN(?)) AND voided = 0",
      new_drug_cms_params[:code], new_drug_cms_params[:name], new_drug_cms_params[:short_name])
    if found_drug_cms.blank?
      begin
        new_drug_cms = DrugCms.create!(new_drug_cms_params)
        if new_drug_cms
          new_drug_cms
        else
          new_drug_cms.errors
        end
      rescue Exception=>e
        e.to_s
      end
    else
      {error: "Drug already exist with same code, name or short_name"}
    end
  end

  #update drug_cmd
  def update_drug_cms(update_params)
    begin
      found_drug_cms = DrugCms.find(update_params[:id])
      if found_drug_cms.update(update_params)
        found_drug_cms
      else
        found_drug_cms.errors
      end
    rescue ActiveRecord::RecordNotFound => e
      e.message
    end
  end

  #search drug_cms
  def search_drug_cms(kwd)
    DrugCms.where("code LIKE('%#{kwd}%') OR name LIKE('%#{kwd}%') OR short_name LIKE('%#{kwd}%')")
  end
end