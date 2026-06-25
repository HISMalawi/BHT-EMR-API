# frozen_string_literal: true

# CohortProgress — lightweight file-backed progress tracker for ART cohort report.
#
# Stored under tmp/cohort_progress/<job_key>.json so it is visible to any Puma
# worker process without requiring Redis or any external store.
#
# Usage (writer side — cohort_builder.rb):
#   key = CohortProgress.key(name, start_date, end_date)
#   CohortProgress.start!(key, steps: CohortProgress::STEPS)
#   CohortProgress.step!(key, :phase1)
#   CohortProgress.done!(key)
#
# Usage (reader side — controller):
#   CohortProgress.read(key)   # => { step:, label:, pct:, elapsed_seconds: }

module CohortProgress
  DIR = Rails.root.join('tmp', 'cohort_progress').freeze

  # Ordered list of named stages with human-readable labels.
  # Order MUST match the sequence of CohortProgress.step! calls in cohort_builder.rb.
  # Weights reflect approximate relative wall-time on a warm DB.
  STEPS = [
    { key: :prepare,      label: 'Preparing tables',                weight: 2  },
    { key: :phase1,       label: 'Loading phase-1 temp tables',     weight: 12 },
    { key: :enroll,       label: 'Building cohort member list',     weight: 5  },
    { key: :demographics, label: 'Computing demographics',          weight: 5  },
    { key: :cum_outcome,  label: 'Computing cumulative outcomes',   weight: 25 },
    { key: :preloads,     label: 'Pre-loading adherence & obs',     weight: 5  },
    { key: :outcomes,     label: 'Computing patient outcomes',      weight: 5  },
    { key: :regimens,     label: 'Calculating regimen categories',  weight: 10 },
    { key: :side_effects, label: 'Checking side effects & TB',      weight: 8  },
    { key: :adherence,    label: 'Processing adherence data',       weight: 12 },
    { key: :preg_bf,      label: 'Pregnant & breastfeeding status', weight: 5  },
    { key: :tpt_fp_bp,    label: 'TPT / FP / BP indicators',       weight: 5  },
    { key: :done,         label: 'Complete',                        weight: 0  }
  ].freeze

  TOTAL_WEIGHT = STEPS.sum { |s| s[:weight] }.to_f

  # Cumulative weight up to (but not including) a given step key.
  PCT_AT = STEPS.each_with_object({ cumulative: 0, map: {} }) do |step, acc|
    acc[:map][step[:key]] = ((acc[:cumulative] / TOTAL_WEIGHT) * 100).round
    acc[:cumulative] += step[:weight]
  end[:map].freeze

  FileUtils.mkdir_p(DIR)

  # ── key helpers ───────────────────────────────────────────────────────────

  # Key is derived from name only so it is consistent whether the caller
  # knows the date range or not (e.g. controller vs background job).
  def self.key(name, _start_date = nil, _end_date = nil)
    Digest::MD5.hexdigest(name.to_s.strip)
  end

  # ── writer API ────────────────────────────────────────────────────────────

  def self.start!(job_key, steps: STEPS)
    write(job_key, {
      job_key:,
      started_at: Time.now.to_f,
      step: :prepare,
      label: steps.first[:label],
      pct: 0,
      done: false
    })
  end

  def self.step!(job_key, step_key)
    existing = raw_read(job_key) || {}
    write(job_key, existing.merge(
      step: step_key,
      label: STEPS.find { |s| s[:key] == step_key }&.dig(:label) || step_key.to_s,
      pct: PCT_AT[step_key] || 99
    ))
  end

  def self.done!(job_key)
    existing = raw_read(job_key) || {}
    write(job_key, existing.merge(step: :done, label: 'Complete', pct: 100, done: true))
  end

  def self.error!(job_key, message)
    existing = raw_read(job_key) || {}
    write(job_key, existing.merge(step: :error, label: "Error: #{message}", pct: -1, done: true))
  end

  # ── reader API ────────────────────────────────────────────────────────────

  def self.read(job_key)
    data = raw_read(job_key)
    return nil unless data

    elapsed = data[:started_at] ? (Time.now.to_f - data[:started_at].to_f).round : 0
    data.merge(elapsed_seconds: elapsed)
  end

  # ── private ───────────────────────────────────────────────────────────────

  def self.path(job_key)
    DIR.join("#{job_key}.json")
  end

  def self.write(job_key, payload)
    target = path(job_key)
    # Use Thread object_id + pid for a unique tmp name across concurrent threads
    tmp = "#{target}.tmp#{Process.pid}_#{Thread.current.object_id}"
    File.write(tmp, payload.to_json)
    File.rename(tmp, target)   # atomic on Linux (same filesystem)
  rescue StandardError => e
    File.delete(tmp) rescue nil
    Rails.logger.warn("CohortProgress write failed: #{e.message}")
  end

  def self.raw_read(job_key)
    file = path(job_key)
    return nil unless File.exist?(file)

    JSON.parse(File.read(file), symbolize_names: true)
  rescue StandardError
    nil
  end

  private_class_method :path, :write, :raw_read
end
