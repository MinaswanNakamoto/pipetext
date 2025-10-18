# pipetext

Easily add colors, boxes, repetitions and emojis to your terminal output using pipes(|).

Install using the Ruby Gem:

> gem install pipetext

Includes a Ruby library module which can be included in your code:

```
require 'pipetext'

class Alice
  include PipeText
  def say(string)
    write("Alice says, '|y#{string}|n'")
  end
end

alice = Alice.new
alice.say("Hello world!")
```

The gem includes a command line interface too (you can find the script in bin):

> pipetext

> pipetext '|Ccyan|n'
