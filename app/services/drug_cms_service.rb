class DrugCmsService

  #search drug_cms
  def search_drug_cms(kwd)
    DrugCms.where("code LIKE('%#{kwd}%') OR name LIKE('%#{kwd}%') OR short_name LIKE('%#{kwd}%')")
  end
end