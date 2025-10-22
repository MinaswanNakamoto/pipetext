#!/usr/bin/env ruby

# Use local file
require 'lib/pipetext'

# Use gem install
#require 'pipetext'

class Alice
  include PipeText
  def say(string)
    write("Alice says, '|y#{string}|n'")
  end
end

class Bob
  include PipeText
  def say(string)
    write("Bob says, '|m#{string}|n'")
  end
end

class Carol
  include PipeText
  def say(string)
    # Defaults to using & for BG colors so no need for |&
    paint("Carol says, '|W&g#{string}&n|n'")
  end
end

alice = Alice.new
bob = Bob.new
carol = Carol.new
alice.say("Hello world!")
bob.say("Oh.. hi Alice! |&|g&rAnd goodbye world time to exit!&n|n")
carol.say("Hey Alice. Bob, you are so melodramatic. Let's transact later.")
pipe = Class.new.extend(PipeText)
pipe.write('Check = |G|U+2714|n, Cross = |R|U+274C |n')
exit!
