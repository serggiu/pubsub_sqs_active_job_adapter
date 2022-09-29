# Active Job PubSub Adapter

This is an implementation of an Active Job adapter using Google's PubSub to enqueue the pending jobs. The implementation uses:

1. a PubSub wrapper class which calls the API
2. an Active Job adapter class which calls the wrapper when enquing the pending job
3. a worker (rake task) which dequeues and runs the pending jobs

Assuming your PubSub credentials file is pubsub.json and is located in the config folder, start the worker to execute pending jobs like this:

```
GOOGLE_APPLICATION_CREDENTIALS=./config/pubsub.json rails worker:run
```

This will spawn a new thread from a pool of threads (line 33 in lib/tasks/worker.rake) and check the received message. If the job is scheduled to run later, we acknowledge the message on PubSub which is telling it to only re-deliver the same message at or after the given execution timestamp (line 69 in lib/tasks/worker.rake).

If the timestamp is not present or it's already in the past, we execute the thread right away and we again acknowledge the message on PubSub (line 73 in lib/tasks/worker.rake) so that this same message is not re-delivered to us while we're processing it. The chosen interval of 2 minutes is just randomly chosen and you can tweak this depending on how long your background jobs take to execute.

There is another rake task which helps test the logic by enqueuing some jobs to be executed. This can be run with:

```
GOOGLE_APPLICATION_CREDENTIALS=./config/pubsub.json rails worker:add_jobs
```

The sample job used can be found inside app/jobs/pubsub_job.rb which might either throw an exception (to test the correct triggering of the re-enqueue-ing logic for the job) or wait for a few seconds then finish the execution. For simple testing purposes  we use **puts** to display messages in the terminal. Insert your own background job logic in there.

# Alternative - using Amazon's SQS to enqueue pending jobs

An alternative to the Google PubSub adapter is to use the Amazon's SQS adapter which is already implemented inside the aws-sdk-rails gem. To use it you'll have to:
1. add the aws-sdk-rails to your gemfile
2. add a config/aws_sqs_active_job.yml where you specify the url for the SQS to be used
3. as a code example we use another background job class (SqsJob) in which we specify the amazon_sqs_async as the queue adapter

The same aws-sdk-rails gem already provides a worker to fetch any pending jobs from an SQS queue and you can run it like this:

```
RAILS_ENV=development bundle exec aws_sqs_active_job --queue default
```

if you specified more than one queue in the aws_sqs_active_job.yml file, you'll change "default" in the above command with the queue that you want to use.

To test this option we can use the rails console like this:

```
SqsJob.perform_later("Run this job on SQS")
```

# License
This is released under the MIT License.