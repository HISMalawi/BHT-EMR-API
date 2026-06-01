puts ConceptName.where("name LIKE '%default%'").pluck(:name).inspect
