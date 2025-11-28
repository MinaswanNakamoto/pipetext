Gem::Specification.new do |s|
  s.name        = "pipetext"
  s.version     = "0.2.2"
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

  Works with files:

  > pipetext <filename>

  Works with pipes too:

  > echo '|RRed test |u1f49c|n' | pipetext

---
  | pipe  ||  & ampersand    &&  Toggle (&) background color mode  |&
  smoke   |s  white          |W  black text on white background    |k&w
  red     |r  bright red     |R  red background      &r
  green   |g  bright green   |G  green background    &g
  blue    |b  bright blue    |B  blue background     &b
  cyan    |c  bright cyan    |C  cyan background     &c
  yellow  |y  bright yellow  |Y  yellow background   &y
  magenta |m  bright magenta |M  magenta background  &m
---
  Hex RGB color codes:    Foreground |#RRGGBB  Background      &#RRGGBB
  Palette colors (256) using Hex:    |p33&pF8  Clear Screen    |!
  black with white background        |K&w      Blinking        |@
  white with magenta background      |w&m      invert          |i
  smoke with green background        |s&g      Underlined      |_
  red with cyan background           |r&c      Italics         |~
  bright red with blue background    |R&b      Bold            |+
  green with yellow background       |g&y      Faint           |.
  bright green with red background   |G&r      Crossed out     |x
  normal color and background        |n&n      Escape Sequence |\\

  Center text using current position and line end number       |{text to center}
  Add spaces to line end             |;         Set line end   |]#
  Set current x,y cursor position    |[x,y]     Terminal bell  |[bell]
  Move cursor up 1 line              |^         Hide cursor    |h
  Move cursor down 1 line            |v         Unhide cursor  |H
  Move cursor forward 1 character    |>         Sleep timer in seconds      |[#s]
  Move cursor back 1 character       |<         Sleep timer in milliseconds |[#ms]
  Capture variable  |(variable name=data)       Display variable        |(variable name)
  Add to variable   |(variable name+=data)      Subtract from variable  |(variable name-=data)
  Multiple variable |(variable name*=data)      Divide variable         |(variable name/=data)
  Copy variable to current number    |(#variable name)

---
  Emojis:  https://unicode.org/emoji/charts/full-emoji-list.html
         |[Abbreviated CLDR Short Name]     😍 |[smiling face with heart-eyes] or
      ⚙  |[gear]   💤 |[zzz]   👨 |[man]    😍 |[sm f w he e]
      ✔  |U2714    ❌ |U274c    ☮ |u262E    💎 |u1f48e    💜 |u1f49c
---

  Single or double line box mode with |- or |=
  
                 ┌──┬──┐ ╔══╦══╗ +--+--+  <-- Draw this with this:  |15 |-[--v--] |=[--v--] |o[--v--]
                 │  │  │ ║  ║  ║ |  |  |                            |15 |-!  !  ! |=!  !  ! |o!  !  !
  123456789012345├──┴──┤ ╠══╩══╣ +--+--+           |y1234567890|g12345|n|->--^--< |=>--^--< |o>--^--< 
  15 Spaces      │     │ ║     ║ |     |                |c15|n Spaces|6 |-!     ! |=!     ! |o!     !
  (|15 )         └─────┘ ╚═════╝ +-----+                      (||15 )|9 |-{-----} |={-----} |o{-----}
  
  ┌──────────────────┐    ╔════════════════════╗            |-[|18-]|4 |g&m|=[|20-]|n&n|O
  │                  │    ║                    ║            |-!|18 !|4 |g&m|=!|20 !|n&n|O
  ├──────────────────┤    ╠════════════════════╣            |->|18-<|4 &m|g|=>|20-<|n&n|O
  │                  │    ║                    ║            |-!|18 !|4 |g&m|=!|20 !|n&n|O
  └──────────────────┘    ╚════════════════════╝            |-{|18-}|4 |g&m|={|20-}|n&n|O
---
  Repetition using | followed by the number of characters to repeat and then the character to repeat.
  |15* does the * character 15 times like this: ***************
---
==Use the ++pipetext++ command to see other options and examples.
"
  s.authors     = ["Minaswan Nakamoto"]
  s.email       = "minaswan.nakamoto@onionmail.org"
  s.files       = ["lib/pipetext.rb", "lib/pipetext/pipetext.rb", "lib/pipetext/version.rb",
                   "lib/pipetext/substitute_emoji_names.rb", "bin/pipetext"]
  s.executables = ["pipetext"]
  s.homepage    = "https://github.com/MinaswanNakamoto/pipetext"
  s.license     = "MIT"
  s.required_ruby_version = ">= 1.8.7"
end
