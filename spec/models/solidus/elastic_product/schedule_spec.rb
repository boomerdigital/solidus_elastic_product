require 'spec_helper'

module Solidus::ElasticProduct
  describe Schedule do

    describe 'serialization' do
      it 'will spin off jobs in batches' do
        old_batch_size = described_class::BATCH_SIZE
        silence_warnings { described_class.const_set 'BATCH_SIZE', 2 }
        begin
          5.times { create :product }
          expect do
            described_class.new.check_and_schedule
          end.to change{ ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by 3
          expect( ActiveJob::Base.queue_adapter.enqueued_jobs.collect {|j| j[:job]}.uniq ).to eq [SerializerJob]
        ensure
          silence_warnings { described_class.const_set 'BATCH_SIZE', old_batch_size }
        end
      end

      it 'provides a method to force serialization of all regardless of state' do
        5.times { create :product }
        expect do
          described_class.serialize_all
        end.to change{ ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by 1
        expect( ActiveJob::Base.queue_adapter.enqueued_jobs.first[:job] ).to eq SerializerJob
      end
    end

    it 'will spin off upload jobs in batches' do
      old_batch_size = described_class::BATCH_SIZE
      silence_warnings { described_class.const_set 'BATCH_SIZE', 2 }
      begin
        5.times { create :product_with_elastic_state, json: '{}' }
        expect do
          described_class.new.check_and_schedule
        end.to change{ ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by 3
        expect( ActiveJob::Base.queue_adapter.enqueued_jobs.collect {|j| j[:job]}.uniq ).to eq [UploaderJob]
      ensure
        silence_warnings { described_class.const_set 'BATCH_SIZE', old_batch_size }
      end
    end

    describe 'monitoring' do
      it 'will continually check for work to be done', no_transaction: true do
        old_time = described_class::CHECK_EVERY
        silence_warnings { described_class.const_set 'CHECK_EVERY', 3.seconds }

        begin
          # Start monitoring nothing to do initially
          monitor = Thread.new { described_class.monitor }

          # Wait to ensure monitor has already done one bit of checking so we know
          # if it does do something it is due to it continually checking
          sleep 1
          expect( ActiveJob::Base.queue_adapter.enqueued_jobs.size ).to eq 0

          # Create a product that needs to be encoded
          create :product_with_elastic_state
          Spree::Product.update_all updated_at: 2.months.ago

          # Wait for the monitor to notice it and queue the job
          sleep 6

          # Verify a job was queued
          expect( ActiveJob::Base.queue_adapter.enqueued_jobs.size ).to eq 1
          expect( ActiveJob::Base.queue_adapter.enqueued_jobs.first[:job] ).to eq SerializerJob

          # Shut it down
          monitor.kill
        ensure
          trap 'TERM', 'DEFAULT'
          silence_warnings { described_class.const_set 'CHECK_EVERY', old_time }
        end
      end

      it 'will stop checking on sigterm' do
        old_time = described_class::CHECK_EVERY
        silence_warnings { described_class.const_set 'CHECK_EVERY', 2.seconds }
        begin
          killer = Thread.new do
            sleep 1
            Process.kill "TERM", Process.pid
          end
          described_class.monitor
          killer.join
          # If we don't block forever this test passes
        ensure
          trap 'TERM', 'DEFAULT'
          silence_warnings { described_class.const_set 'CHECK_EVERY', old_time }
        end
      end
    end

  end
end
