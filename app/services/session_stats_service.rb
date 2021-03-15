# frozen_string_literal: true

# Returns various statistics (reports) for the currently logged in user
class SessionStatsService
  attr_accessor :user, :date

  def initialize(user, date)
    @user = user
    @date = date
  end

  # Returns total visits on given day and visits facilitated by current user
  def visits
    {
      all_visits: day_stats_service.visits_count,
      user_visits: visits_count
    }
  end

  # Returns a count of all visits handled by current user on given day
  def visits_count
    user_id = ActiveRecord::Base.connection.quote(user.user_id)
    day_bounds = TimeUtils.day_bounds date
    day_start = ActiveRecord::Base.connection.quote(day_bounds[0])
    day_end = ActiveRecord::Base.connection.quote(day_bounds[1])

    row = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT sum(visitor) as total_visitors FROM
        (SELECT 1 as visitor FROM encounter
         WHERE creator = #{user_id}
          AND encounter_datetime BETWEEN #{day_start} AND #{day_end}
          AND voided = 0
         GROUP BY patient_id) AS visitors
    SQL

    row['total_visitors'] || 0
  end

  private

  def day_stats_service
    DayStatsService.new date
  end
end
