# frozen_string_literal: true

module MnhService
  class Engine
    LOGGER = Rails.logger

    def stats(program_id, date = nil)
      program = Program.find(program_id)
      name = program.name.to_s.upcase.strip

      if anc_program?(name)
        anc_stats(program_id, date)
      elsif labour_program?(name)
        labour_stats(program_id, date)
      else
        raise ArgumentError, "Program #{program_id} is not ANC or Labour (name: #{program.name})"
      end
    end

    def anc_stats(program_id = nil, date = nil)
      result = MnhService::AncStatsQueries.new(program_id).stats_hash(date)
      result[:date] = format_date(date) if date.present?
      LOGGER.info "[MnhService::Engine] anc_stats program_id=#{program_id} date=#{date}"
      result
    end

    def labour_stats(program_id = nil, date = nil)
      result = MnhService::LabourStatsQueries.new(program_id, date).stats_hash
      result[:date] = format_date(date) if date.present?
      LOGGER.info "[MnhService::Engine] labour_stats program_id=#{program_id} date=#{date}"
      result
    end

    private

    def anc_program?(name)
      name == 'ANC PROGRAM'
    end

    def labour_program?(name)
      name == 'LABOUR AND DELIVERY PROGRAM'
    end

    def format_date(date)
      date.respond_to?(:to_date) ? date.to_date.iso8601 : date.to_s
    end
  end
end
