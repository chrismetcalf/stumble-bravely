# A convenience library so you can fake out your Tropo script when you're
# running in irb
#
# Just "require 'fake_tropo'" in irb, and it'll log Tropo requests to stdout

def answer
  puts "ANSWERING"
end

def say(message)
  puts "SAY: #{message}"
end

def ask(message, options)
  puts "ASKING: #{message} WITH OPTIONS #{options.inspect}"
end

def log(message)
  puts "LOG: #{message}"
end

def hangup
  puts "HANGING UP"
end
