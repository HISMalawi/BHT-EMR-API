# A note on handling time in the application

All time saved to the database must be saved in UTC (ie with the timezone trimmed off).
Rails handles this for us by default, however there are some date operations that
can cause problems.

- Use of `to_datetime` - This method is not timezone aware thus any datetimes
  generated using this method will be off by about 2 hours (assuming you are
  using CAT as your timezone). Use `to_time` instead.

- If you have the urge to compare ruby dates to database datetime fields, it's
  best you use ruby times instead and cast them to date in the database as
  follows:

  ```ruby
  # Don't do this:
  date = '2001-01-01'.to_date
  Observation.where 'DATE(obs_datetime) = ?', date

  # Rather do this:
  time = '2001-01-01'.to_time
  Observation.where('DATE(obs_datetime) = DATE(?)', time)
  ```

- Never ever pass dates or time as plain strings to the datebase. Pass either ruby dates or times.
  If you have to call `strftime` on any date or time objects immediately convert it back
  to a time object.

NOTE: There is a utility module for dealing with time. Find it at `app/utils/TimeUtils.rb`.
