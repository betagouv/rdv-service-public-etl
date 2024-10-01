require 'optparse'
require 'dotenv'

require_relative "lib/job"

Dotenv.load

app = nil
async = false
OptionParser.new do |opts|
  opts.on('-a', '--app APP', Apps.valid_names) { app = _1 }
  opts.on('--async') { async = true }
end.parse!

if async
  Job.perform_async(app)
else
  Job.new.perform(app)
end
