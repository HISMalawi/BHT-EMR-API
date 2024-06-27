# frozen_string_literal: true

module Lab
  module Lims
    module Api
      class MysqlApi
        def self.start
          instance = MysqlApi.new
          orders_processed = 0
          instance.consume_orders(from: 0, limit: 1000) do |order|
            puts "Order ##{orders_processed}"
            pp order
            orders_processed += 1
            puts
          end
        end

        def initialize(processes: 1, on_merge_processes: nil)
          @processes = processes
          @on_merge_processes = on_merge_processes
          @mysql_connection_pool = {}
        end

        def multiprocessed?
          @processes > 1
        end

        def consume_orders(from: nil, limit: 1000)
          loop do
            specimens_to_process = specimens(from, limit)
            break if specimens_to_process.size.zero?

            processes = multiprocessed? ? @processes : 0
            on_merge_processes = ->(_item, index, _result) { @on_merge_processes&.call(from + index) }

            Parallel.map(specimens_to_process, in_processes: processes, finish: on_merge_processes) do |specimen|
              User.current ||= Utils.lab_user

              tests = specimen_tests(specimen['specimen_id'])
              results = tests.each_with_object({}) do |test, object|
                object[test['test_name']] = test_results(test['test_id'])
              end

              dto = make_order_dto(
                specimen: specimen,
                patient: specimen_patient(specimen['specimen_id']),
                test_results: results,
                specimen_status_trail: specimen_status_trail(specimen['specimen_id']),
                test_status_trail: tests.each_with_object({}) do |test, trails|
                  trails[test['test_name']] = test_status_trail(test['test_id'])
                end
              )

              yield dto, OpenStruct.new(last_seq: from)
            end

            from += limit
          end
        end

        def parallel_map(items, on_merge: nil, &block); end

        private

        def specimens(start_id, limit)
          query = <<~SQL
            SELECT specimen.id AS specimen_id,
                   specimen.couch_id AS doc_id,
                   specimen_types.name AS specimen_name,
                   specimen.tracking_number,
                   specimen.priority,
                   specimen.target_lab,
                   specimen.sending_facility,
                   specimen.drawn_by_id,
                   specimen.drawn_by_name,
                   specimen.drawn_by_phone_number,
                   specimen.ward_id,
                   specimen_statuses.name AS specimen_status,
                   specimen.district,
                   specimen.date_created AS order_date
            FROM specimen
            INNER JOIN specimen_types ON specimen_types.id = specimen.specimen_type_id
            INNER JOIN specimen_statuses ON specimen_statuses.id = specimen.specimen_status_id
          SQL

          query = "#{query} WHERE specimen.id > #{sql_escape(start_id)}" if start_id
          query = "#{query} LIMIT #{limit.to_i}"

          Rails.logger.debug(query)
          query(query)
        end

        ##
        # Pull patient associated with given specimen
        def specimen_patient(specimen_id)
          results = query <<~SQL
            SELECT patients.patient_number AS nhid,
                   patients.name,
                   patients.gender,
                   DATE(patients.dob) AS birthdate
            FROM patients
            INNER JOIN tests
              ON tests.patient_id = patients.id
              AND tests.specimen_id = #{sql_escape(specimen_id)}
            LIMIT 1
          SQL

          results.first
        end

        def specimen_tests(specimen_id)
          query <<~SQL
            SELECT tests.id AS test_id,
                   test_types.name AS test_name,
                   tests.created_by AS drawn_by_name
            FROM tests
            INNER JOIN test_types ON test_types.id = tests.test_type_id
            WHERE tests.specimen_id = #{sql_escape(specimen_id)}
          SQL
        end

        def specimen_status_trail(specimen_id)
          query <<~SQL
            SELECT specimen_statuses.name AS status_name,
                   specimen_status_trails.who_updated_id AS updated_by_id,
                   specimen_status_trails.who_updated_name AS updated_by_name,
                   specimen_status_trails.who_updated_phone_number AS updated_by_phone_number,
                   specimen_status_trails.time_updated AS date
            FROM specimen_status_trails
            INNER JOIN specimen_statuses
              ON specimen_statuses.id = specimen_status_trails.specimen_status_id
            WHERE specimen_status_trails.specimen_id = #{sql_escape(specimen_id)}
          SQL
        end

        def test_status_trail(test_id)
          query <<~SQL
            SELECT test_statuses.name AS status_name,
                   test_status_trails.who_updated_id AS updated_by_id,
                   test_status_trails.who_updated_name AS updated_by_name,
                   test_status_trails.who_updated_phone_number AS updated_by_phone_number,
                   COALESCE(test_status_trails.time_updated, test_status_trails.created_at) AS date
            FROM test_status_trails
            INNER JOIN test_statuses
              ON test_statuses.id = test_status_trails.test_status_id
            WHERE test_status_trails.test_id = #{sql_escape(test_id)}
          SQL
        end

        def test_results(test_id)
          query <<~SQL
            SELECT measures.name AS measure_name,
                   test_results.result,
                   test_results.time_entered AS date
            FROM test_results
            INNER JOIN measures ON measures.id = test_results.measure_id
            WHERE test_results.test_id = #{sql_escape(test_id)}
          SQL
        end

        def make_order_dto(specimen:, patient:, test_status_trail:, specimen_status_trail:, test_results:)
          drawn_by_first_name, drawn_by_last_name = specimen['drawn_by_name']&.split
          patient_first_name, patient_last_name = patient['name'].split

          OrderDTO.new(
            _id: specimen['doc_id'].blank? ? SecureRandom.uuid : specimen['doc_id'],
            _rev: '0',
            tracking_number: specimen['tracking_number'],
            date_created: specimen['order_date'],
            sample_type: specimen['specimen_name'],
            tests: test_status_trail.keys,
            districy: specimen['district'], # districy [sic] - That's how it's named
            order_location: specimen['ward_id'],
            sending_facility: specimen['sending_facility'],
            receiving_facility: specimen['target_lab'],
            priority: specimen['priority'],
            patient: {
              id: patient['nhid'],
              first_name: patient_first_name,
              last_name: patient_last_name,
              gender: patient['gender'],
              birthdate: patient['birthdate'],
              email: nil,
              phone_number: nil
            },
            type: 'Order',
            who_order_test: {
              first_name: drawn_by_first_name,
              last_name: drawn_by_last_name,
              id: specimen['drawn_by_id'],
              phone_number: specimen['drawn_by_phone_number']
            },
            sample_status: specimen['specimen_status'],
            sample_statuses: specimen_status_trail.each_with_object({}) do |trail_entry, object|
              first_name, last_name = trail_entry['updated_by_name'].split

              object[format_date(trail_entry['date'])] = {
                status: trail_entry['status_name'],
                updated_by: {
                  first_name: first_name,
                  last_name: last_name,
                  phone_number: trail_entry['updated_by_phone_number'],
                  id: trail_entry['updated_by_id']
                }
              }
            end,
            test_statuses: test_status_trail.each_with_object({}) do |trail_entry, formatted_trail|
              test_name, test_statuses = trail_entry

              formatted_trail[test_name] = test_statuses.each_with_object({}) do |test_status, formatted_statuses|
                updated_by_first_name, updated_by_last_name = test_status['updated_by_name'].split

                formatted_statuses[format_date(test_status['date'])] = {
                  status: test_status['status_name'],
                  updated_by: {
                    first_name: updated_by_first_name,
                    last_name: updated_by_last_name,
                    phone_number: test_status['updated_by_phone_number'],
                    id: test_status['updated_by_id']
                  }
                }
              end
            end,
            test_results: test_results.each_with_object({}) do |results_entry, formatted_results|
              test_name, results = results_entry

              formatted_results[test_name] = format_test_result_for_dto(test_name, specimen, results, test_status_trail)
            end
          )
        end

        def format_test_result_for_dto(test_name, specimen, results, test_status_trail)
          return {} if results.size.zero?

          result_create_event = test_status_trail[test_name]&.find do |trail_entry|
            trail_entry['status_name'].casecmp?('drawn')
          end

          result_creator_first_name, result_creator_last_name = result_create_event&.fetch('updated_by_name')&.split
          unless result_creator_first_name
            result_creator_first_name, result_creator_last_name = specimen['drawn_by_name']&.split
          end

          {
            results: results.each_with_object({}) do |result, formatted_measures|
              formatted_measures[result['measure_name']] = {
                result_value: result['result']
              }
            end,
            date_result_entered: format_date(result_create_event&.fetch('date') || specimen['order_date'], :iso),
            result_entered_by: {
              first_name: result_creator_first_name,
              last_name: result_creator_last_name,
              phone_number: result_create_event&.fetch('updated_by_phone_number') || specimen['drawn_by_phone_number'],
              id: result_create_event&.fetch('updated_by_id') || specimen['updated_by_id']
            }
          }
        end

        def mysql
          return mysql_connection if mysql_connection

          config = lambda do |key|
            @config ||= Lab::Lims::Config.database
            @config['default'][key] || @config['development'][key]
          end

          connection = Mysql2::Client.new(host: config['host'] || 'localhost',
                                          username: config['username'] || 'root',
                                          password: config['password'],
                                          port: config['port'] || '3306',
                                          database: config['database'],
                                          reconnect: true)

          self.mysql_connection = connection
        end

        def pid
          return -1 if Parallel.worker_number.nil?

          Parallel.worker_number
        end

        def mysql_connection=(connection)
          @mysql_connection_pool[pid] = connection
        end

        def mysql_connection
          @mysql_connection_pool[pid]
        end

        def query(sql)
          Rails.logger.debug("#{MysqlApi}: #{sql}")
          mysql.query(sql)
        end

        def sql_escape(value)
          mysql.escape(value.to_s)
        end

        ##
        # Lims has some weird date formatting standards...
        def format_date(date, format = nil)
          date = date&.to_time

          case format
          when :iso
            date&.strftime('%Y-%m-%d %H:%M:%S')
          else
            date&.strftime('%Y%m%d%H%M%S')
          end
        end
      end
    end
  end
end
