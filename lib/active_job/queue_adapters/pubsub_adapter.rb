# frozen_string_literal: true

module ActiveJob
  module QueueAdapters
    class PubsubAdapter
      # Enqueue a job to be performed.
      def enqueue(job)
        Pubsub.push_to_queue(job.serialize)
      end

      # Enqueue a job to be performed at a certain time.
      def enqueue_at(job, timestamp)
        Pubsub.push_to_queue(job.serialize, timestamp)
      end
    end
  end
end
