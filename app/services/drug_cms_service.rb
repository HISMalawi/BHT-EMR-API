# frozen_string_literal: true

# DrugCmsService is a service class for DrugCMS
class DrugCmsService
  def search_drug_cms(kwd)
    DrugCms.where("code LIKE('%#{kwd}%') OR name LIKE('%#{kwd}%') OR short_name LIKE('%#{kwd}%')")
  end
end
