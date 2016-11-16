if Rails.env.development? || Rails.env.test?
  require "log_buddy"
  require "awesome_print"

  LogBuddy.init(
    logger: Logger.new('log/awesome.log'),
    use_awesome_print: true
  )
end
