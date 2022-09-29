# frozen_string_literal: true

class SqsJob < ActiveJob::Base
  queue_as(:default)
  self.queue_adapter = :amazon_sqs_async

  retry_on(StandardError, wait: 1.minute, attempts: 2)

  def perform(*args)
    puts("\n ^^ [SQS] Run: #{args.first} \n")
    # for some jobs throw an exception to test retries
    throw(StandardError) if rand(2).zero?
    # take between 0 to 5 seconds to execute
    sleep(rand(5))
    # if we get to this line, just show a simple message
    puts("\n ^^ [SQS] Completed #{args.first}! \n")
  end
end
