class Audit < ApplicationRecord
  self.table_name = 'audits'
  
  has_one :user, foreign_key: :user_id, primary_key: :user_id

  def as_json(options = {})
    super(options.merge(
      methods: %i[changes last_login],
      include: {
        user: {}
      },
      except: %i[audited_changes]
    ))
  end

  def changes
    permitted_classes = [Date, Time]
    json = Psych.safe_load(audited_changes, permitted_classes: permitted_classes)

    if action == 'update'
        return json.map do |key, value|
            {key => {previous: value[0], current: value[1]}}
        end
    end
  end

  def last_login
    user&.date_changed
  end
end