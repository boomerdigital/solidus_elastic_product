# Based on http://stackoverflow.com/a/11268945/120067
class SqlCounter< ActiveSupport::LogSubscriber

  def self.log= boolean
    Thread.current['query_count_logging'] = boolean
  end

  def self.log
    Thread.current['query_count_logging'] || false
  end

  def self.count= value
    Thread.current['query_count'] = value
  end

  def self.count
    Thread.current['query_count'] || 0
  end

  def self.reset_count
    result, self.count = self.count, 0
    result
  end

  def sql(event)
    self.class.count += 1
    puts "logged #{event.payload[:sql]}" if self.class.log
  end
end

SqlCounter.attach_to :active_record
