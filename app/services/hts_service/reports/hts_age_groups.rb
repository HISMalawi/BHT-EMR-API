module HtsService::Reports::HtsAgeGroups
  def hts_age_groups
    [
      { less_than_one: "<1 year" },
      { one_to_four: "1-4 years" },
      { five_to_nine: "5-9 years" },
      { ten_to_fourteen: "10-14 years" },
      { fifteen_to_nineteen: "15-19 years" },
      { twenty_to_twenty_four: "20-24 years" },
      { twenty_five_to_twenty_nine: "25-29 years" },
      { thirty_to_thirty_four: "30-34 years" },
      { thirty_five_to_thirty_nine: "35-39 years" },
      { fourty_to_fourty_four: "40-44 years" },
      { fourty_five_to_fourty_nine: "45-49 years" },
      { fifty_to_fifty_four: "50-54 years" },
      { fifty_five_to_fifty_nine: "55-59 years" },
      { sixty_to_sixty_four: "60-64 years" },
      { sixty_five_to_sixty_nine: "65-69 years" },
      { seventy_to_seventy_four: "70-74 years" },
      { seventy_five_to_seventy_nine: "75-79 years" },
      { eighty_to_eighty_four: "80-84 years" },
      { eighty_five_to_eighty_nine: "85-89 years" },
      { ninety_plus: "90 plus years" },
    ].freeze
  end

  def less_than_one(patients)
    patients.where(person: { birthdate: 1.day.ago..Date.today })
  end

  def one_to_four(patients)
    patients.where(person: { birthdate: 4.years.ago..1.year.ago })
  end

  def five_to_nine(patients)
    patients.where(person: { birthdate: 9.years.ago..4.years.ago })
  end

  def ten_to_fourteen(patients)
    patients.where(person: { birthdate: 14.years.ago..9.years.ago })
  end

  def fifteen_to_nineteen(patients)
    patients.where(person: { birthdate: 19.years.ago..14.years.ago })
  end

  def twenty_to_twenty_four(patients)
    patients.where(person: { birthdate: 24.years.ago..19.years.ago })
  end

  def twenty_five_to_twenty_nine(patients)
    patients.where(person: { birthdate: 29.years.ago..24.years.ago })
  end

  def thirty_to_thirty_four(patients)
    patients.where(person: { birthdate: 34.years.ago..29.years.ago })
  end

  def thirty_five_to_thirty_nine(patients)
    patients.where(person: { birthdate: 39.years.ago..34.years.ago })
  end

  def fourty_to_fourty_four(patients)
    patients.where(person: { birthdate: 44.years.ago..39.years.ago })
  end

  def fourty_five_to_fourty_nine(patients)
    patients.where(person: { birthdate: 49.years.ago..44.years.ago })
  end

  def fifty_to_fifty_four(patients)
    patients.where(person: { birthdate: 54.years.ago..49.years.ago })
  end

  def fifty_five_to_fifty_nine(patients)
    patients.where(person: { birthdate: 59.years.ago..54.years.ago })
  end

  def sixty_to_sixty_four(patients)
    patients.where(person: { birthdate: 64.years.ago..59.years.ago })
  end

  def sixty_five_to_sixty_nine(patients)
    patients.where(person: { birthdate: 69.years.ago..64.years.ago })
  end

  def seventy_to_seventy_four(patients)
    patients.where(person: { birthdate: 74.years.ago..69.years.ago })
  end

  def seventy_five_to_seventy_nine(patients)
    patients.where(person: { birthdate: 79.years.ago..74.years.ago })
  end

  def eighty_to_eighty_four(patients)
    patients.where(person: { birthdate: 84.years.ago..79.years.ago })
  end

  def eighty_five_to_eighty_nine(patients)
    patients.where(person: { birthdate: 89.years.ago..84.years.ago })
  end

  def ninety_plus(patients)
    patients.where.not(person: { birthdate: 90.years.ago..Float::INFINITY })
  end

  def zero_to_nine(patients)
    patients.where(person: { birthdate: 9.years.ago..Date.today })
  end

  def ten_to_nineteen(patients)
    patients.where(person: { birthdate: 19.years.ago..10.years.ago })
  end

  def twenty_plus(patients)
    patients.where.not(person: { birthdate: 20.years.ago..Float::INFINITY })
  end
end
