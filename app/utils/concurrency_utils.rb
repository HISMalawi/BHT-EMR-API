# frozen_string_literal: true

module ConcurrencyUtils
  LOCK_FILES_DIR_PATH = Rails.root.join('tmp', 'locks')

  def with_lock(lock_file_path, blocking: true)
    path = LOCK_FILES_DIR_PATH.join(lock_file_path)

    unless Dir.exist?(path.dirname)
      Rails.logger.debug("Creating lock file directory: #{path.dirname}")
      FileUtils.mkdir_p(path.dirname)
    end

    File.open(path, 'w') do |lock_file|
      Rails.logger.debug("Attempting to acquire lock: #{lock_file_path}")
      locking_mode = blocking ? File::LOCK_EX : File::LOCK_NB | File::LOCK_EX
      if blocking && !lock_file.flock(locking_mode)
        raise FailedToAcquireLock, "Lock #{lock_file_path} is locked by another process"
      end

      lock_file.write("Locked by process ##{Process.pid} at #{Time.now}")
      yield
    end
  end
end
