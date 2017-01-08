# Object to look at the DB to determine if work needs to be done and schedule
# that work to accomplish it.

module Solidus::ElasticProduct
  class Schedule
    BATCH_SIZE = 600
    CHECK_EVERY = 1.minute

    class << self
      # Enters into an infinate loop where we monitor the DB looking for work that
      # needs to be done and fires off workers to handle that work.
      #
      # Designed to be executed as a deamon so if SIGTERM is sent to the process
      # it will finish the current loop then exit cleanly.
      def monitor
        should_exit = false
        trap('TERM') { should_exit = true }

        until should_exit do
          new.check_and_schedule
          sleep CHECK_EVERY
        end
      end

      # Prior to running the initialization job if we have a lot of unserialized
      # product, you can run this method to schedule getting it serialized.
      def serialize_all
        new.serialize_all
      end
    end

    # Checks the DB for work and schedules it if necessary
    def check_and_schedule
      return unless Config.incremental_update_enabled
      Rails.logger.info "Checking for work"
      serialize
      upload
    end

    def serialize_all # :nodoc:
      serialize State.all
    end

    private

    # If records need to be serialized kick off workers to handle them in batches.
    def serialize scope = State.needing_serialization
      assign_to job: :serializer, lock: :locked_for_serialization_at, scope: scope
    end

    # If records need to be uploaded kick off workers to handle them in batches
    def upload
      scope = State.needing_upload
      assign_to job: :uploader, lock: :locked_for_upload_at, scope: scope
    end

    # Will actually load the records that need to be batched and assign each
    # to a job for a worker to handle.
    def assign_to job:, lock:, scope:
      Rails.logger.info "Found work for: #{job}"
      table = State.table_name

      scope.select("#{table}.id, #{table}.product_id").find_in_batches batch_size: BATCH_SIZE do |batch|
        product_ids = batch.collect &:product_id
        scope.where(product_id: product_ids).update_all lock => Time.current
        Solidus::ElasticProduct::const_get("#{job.to_s.camelize}Job").perform_later product_ids unless product_ids.empty?
      end
    end
  end
end
