# frozen_string_literal: true

require("json")
require("google/cloud/pubsub")

class Pubsub
  # adding some prefixes for the topic and subscription
  TOPIC_PREFIX = "ajob-queue-"
  SUBSCRIPTION_PREFIX = "ajob-sub-"
  FAILED_TOPIC = "ajob-failed"

  # find or create a topic.
  def self.topic(queue_name)
    name = "#{TOPIC_PREFIX}-#{queue_name}"
    client.topic(name) || client.create_topic(name)
  end

  # find or create a subscription.
  def self.subscription(queue_name)
    name = "#{SUBSCRIPTION_PREFIX}-#{queue_name}"
    topic(queue_name).subscription(name) || topic(queue_name).subscribe(name)
  end

  # enqueue a job on PubSub.
  def self.push_to_queue(job_data, timestamp = 0)
    # puts("\n ^^ [ADD JOB] #{job_data.inspect} \n")
    topic(job_data["queue_name"]).publish(JSON.dump(job_data), { timestamp: timestamp })
  end

  # enqueue a job on the failed topic on PubSub.
  def self.push_to_failed_queue(job_data_str)
    # puts("\n ^^ [ADD FAILED] #{job_data_str} \n")
    topic(FAILED_TOPIC).publish(job_data_str)
  end

  class << self
    private

    # Create a new client.
    def client
      @client ||= Google::Cloud::PubSub.new
    end
  end
end
