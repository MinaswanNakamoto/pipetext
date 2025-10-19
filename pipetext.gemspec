Gem::Specification.new do |s|
  s.name        = "pipetext"
  s.version     = "0.0.6"
  s.summary     = "Use pipe (|) characters to easily add colors, boxes and emojis in the terminal."
  s.description = "== Easily add colors, boxes, repetitions and emojis to your terminal output using pipes (|).
  
  Install using the Ruby Gem:
  
  > gem install pipetext
  
  Includes a Ruby library module which can be included in your code:
  
  require 'pipetext'

  class YellowPrinter
    include PipeText
    def print(string)
      write('|Y' + string + '|n')
    end
  end

  printer = YellowPrinter.new
  printer.print('This is yellow')
  
  The gem includes a command line interface too:
  
  > pipetext

  > pipetext '|Ccyan|n'
  
Use the ++pipetext++ command to see other options and examples.
"
  s.authors     = ["Minaswan Nakamoto"]
  s.email       = "minaswan.nakamoto@onionmail.org"
  s.files       = ["lib/pipetext.rb", "bin/pipetext"]
  s.executables = ["pipetext"]
  s.homepage    = "https://github.com/MinaswanNakamoto/pipetext"
  s.license     = "MIT"
end
