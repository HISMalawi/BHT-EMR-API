# frozen_string_literal: true

module ConcurrencyUtils
  LOCK_FILES_DIR_PATH = Rails.root.join('tmp', 'locks')

  ##
  # Acquire a lock and run the given block of code.
  #
  # The locking mechanism uses files to allow for blocking across processes.
  # This is useful for example in situations where you only want to run one
  # instance of a report.
  #
  # Parameters:
  #   lock_file_path: A relative path to the lock file (allows for namespacing your locks, eg art_service/regimens.lock)
  #   blocking: If lock can not be acquired wait else throw an error (defaults to true)
  #
  # Raises:
  #   FailedToAcquireLock: When lock couldn't be acquired and blocking is set to false
  #
  # Usage:
  #   class Someclass
  #     include ModelUtils
  #
  #     def do_something
  #       with_lock('mylockfile.lock') do
  #         # Run some task requiring exclusive access to some resource
  #       end
  #     end
  #   end
  #
  #   SomeClass.new.do_something
  def with_lock(lock_file_path, blocking: true)
    path = LOCK_FILES_DIR_PATH.join(lock_file_path)

    unless Dir.exist?(path.dirname)
      Rails.logger.debug("Creating lock file directory: #{path.dirname}")
      FileUtils.mkdir_p(path.dirname)
    end

    File.open(path, 'w') do |lock_file|
      Rails.logger.debug("Attempting to acquire lock: #{lock_file_path}")
      locking_mode = blocking ? File::LOCK_EX : File::LOCK_NB | File::LOCK_EX
      unless blocking || lock_file.flock(locking_mode)
        raise FailedToAcquireLock, "Lock #{lock_file_path} is locked by another process"
      end

      lock_file.write("Locked by process ##{Process.pid} at #{Time.now}")
      yield
    end
  end
end
