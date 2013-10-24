module GearMonitor

  require 'rubygems'
  require 'erb'
  require 'pony'

  def self.storage_check
  end

  def self.memory_check
    process_list = %x[ps axeo pid,rss,cmd | sed 1d].split("\n")
    memory_usage = 0
    process_list_ordered = process_list.inject({}) do |r, line|
      line.strip!
      pid, rss, command = line.match(/^(\d+)\s+(\d+)\s+(.*)$/).to_a[1..3]
      memory_usage += rss.to_i*1024
      r[pid.to_i] = { :rss => rss.to_i*1024, :cmd => command }
      r
    end.sort_by { |key, value| value[:rss] }.reverse[0..5]
    result = {
      memory_limit: %x[oo-cgroup-read memory.limit_in_bytes].strip.to_i,
      memory_usage: memory_usage,
      processes: process_list_ordered
    }
    alarm(:memory, result) if memory_usage >= result[:memory_limit]*0.9
  end

  def self.alarm(type, opts={})
    if type == :memory
      data = {
        :body => ERB.new(
          File.read(File.join(ENV['OPENSHIFT_GEAR_MONITOR_DIR'], 'templates', 'memory.erb'))
        ).result(binding),
        :subject => "[ALARM] Application #{ENV['OPENSHIFT_GEAR_NAME']} use 90% of gear memory."
      }
    end
    Pony.mail(
      :to => ENV['NOTIFICATION_EMAIL'],
      :from => "#{ENV['OPENSHIFT_GEAR_NAME']}@openshift.com",
      :body => data[:body],
      :subject => data[:subject]
    )
  end

end
