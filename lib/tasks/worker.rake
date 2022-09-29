# frozen_string_literal: true

require("concurrent/scheduled_task")
require("concurrent/timer_task")

MAX_RUN_TIME = 2.minutes.to_i

namespace(:worker) do
  desc("Test the logic of our PubSub worker")
  task(add_jobs: :environment) do
    runs = 0
    task = Concurrent::TimerTask.new(execution_interval: 1) do |task|
      puts "\n ^^ Add a new job then rest. \n"
      PubsubJob.perform_later("Job #{runs * 1000 + rand(555)}")
      runs += 1
      # shut down after running for a while
      if runs >= 10
        puts "\n ^^ Tea break! \n"
        task.shutdown 
      end
    end
    # start running the task
    task.execute
    # Block, letting task continue in the background
    sleep
  end

  desc("Run the worker")
  task(run: :environment) do
    # See https://googleapis.dev/ruby/google-cloud-pubsub/latest/index.html
    puts("Worker starting...")
    # start pulling messages from PubSub
    subscriber = Pubsub.subscription("default").listen(threads: { callback: 1 }) do |message|
      # puts "\n ^^ Received: #{message.inspect} \n"
      # extract the job and do what is needed
      execute_job(message, message.attributes['timestamp'])
    end
    subscriber.on_error do |error|
      puts("[SUB] Exception: #{error.class} #{error.message}") # handle errors
    end
    # Gracefully shut down the subscriber on program exit, blocking until
    # all received messages have been processed or 10 seconds have passed
    at_exit do
      subscriber.stop!(10)
    end
    # Start background threads that will call the block passed to listen
    subscriber.start
    # Block, letting processing threads continue in the background
    sleep
  end

  def run_job(message, job_data)
    # puts "\n ^^ Executing job: #{job_data.inspect} \n"
    # execute the fetched job
    ActiveJob::Base.execute(job_data)
  rescue StandardError => e
    puts("\n ^^^ Failed #{job_data['arguments'].first} with error: #{e.message} \n")
    # message retried the given number of times, move to the failed queue
    Pubsub.push_to_failed_queue(message.data)
  end

  # receives a Google::Cloud::PubSub::Message
  def execute_job(message, timestamp = 0)
    puts("\n ^^ Received: #{message.message_id} at: #{Time.now} with timestamp: #{timestamp} \n")
    
    if(delay = timestamp.to_i - Time.now.to_i) > 0
      puts "\n ^^ Delay execution for #{message.message_id} with #{delay} seconds. \n"
      # delay the next delivery of the message until the execution time
      message.modify_ack_deadline!(delay)
    else
      # we do not want to receive this same message while we're processing it
      # so we're telling PubSub to only send it again in a chosen time interval
      message.modify_ack_deadline!(MAX_RUN_TIME)
      # format the data so that we can use it
      job_data = JSON.parse(message.data)
      # execute the job
      run_job(message, job_data)
      puts("\n ^^ Ack #{message.message_id} on PubSub. \n")
      # mark the message as received
      message.acknowledge!
    end
  end
end
