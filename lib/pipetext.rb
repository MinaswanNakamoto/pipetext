module PipeText

  public

  def pipetext(text, box_mode = true, ampersand_mode = false)
    attributes = {
      'pipe'            => false,          # Pipe already been found?
      'repeat_pattern'  => false,          # Used by |<#>~repeat pattern~
      'pattern'         => String.new,     # Used by |<#>~repeat pattern~ to capture
      'pattern_escape'  => false,          # Has an escape \ already been found in front of this character?
      'ampersand'       => false,          # Has an ampersand already been found in front of this character?
      'ampersand_mode'  => ampersand_mode, # Do we even process ampersands for background colors?
      'blink'           => false,          # Is blink turned on?
      'bold'            => false,
      'crossed_out'     => false,
      'faint'           => false,
      'found'           => false,          # At the end -- did we find a match?
      'italic'          => false,
      'inverse'         => false,
      'underline'       => false,
      'box'             => -1,             # Default to |O (no boxes)
      'box_mode'        => box_mode,
      'num'             => 0,              # Number of times to repeat pattern
      'unicode_capture' => 0,              # Used to capture Unicode using 6 character UTF-16 hex format
      'unicode'         => String.new,
      'palette_capture' => 0,              # Used to capture 8-bit color using 2 character hex format
      'p'               => String.new,     # |p00 to |pFF
      'color_capture'   => 0,              # Used to capture RGB color using #RRGGBB format
      'r'               => String.new,
      'g'               => String.new,
      'b'               => String.new,
      'fg'              => String.new,     # Needed to restore after background change
      'bg'              => String.new      # Needed to restore after foreground change
    }
    new_text = String.new
    text.chars.each do |character|
      process_character(character, new_text, attributes)
    end
    # Clean up in case we've captured something we didn't process yet
    if(attributes['color_capture'] > 0)
      emit_color(new_text, attributes)
    elsif(attributes['palette_capture'] > 0)
      emit_palette_color(new_text, attributes)
    elsif(attributes['unicode_capture'] > 0)
      emit_unicode(new_text, attributes)
    end
    return new_text
  end

  def write(text, box_mode = true, ampersand_mode = false)
    puts(pipetext(text, box_mode, ampersand_mode))
  end

  # Defaults to using & for background colors
  def paint(text, box_mode = true, ampersand_mode = true)
    puts(pipetext(text, box_mode, ampersand_mode))
  end

  private

  def process_character(character, new_text, attributes)
    if(attributes['repeat_pattern'] == false)
      # Will still need to process character, first process incorrect formats
      if(attributes['color_capture'] > 0 && character !~ /[0-9,A-F,a-f]/)
        emit_color(new_text, attributes)
      elsif(attributes['palette_capture'] > 0 && character !~ /[0-9,A-F,a-f]/)
        emit_palette_color(new_text, attributes)
      elsif(attributes['unicode_capture'] > 0 && character !~ /[0-9,A-F,a-f,+]/ ||
          (attributes['unicode_capture'] != 1 && character == '+'))
        emit_unicode(new_text, attributes)
      end
    end
    if(character == '|' && attributes['repeat_pattern'] == false)
      process_pipe(character, new_text, attributes)
    elsif(character == '~' && attributes['pipe'] == true &&
        attributes['num'] > 0 && attributes['pattern_escape'] == false)
      process_repeat_pattern(character, new_text, attributes)
    elsif(attributes['repeat_pattern'] == true)
      capture_character_pattern(character, attributes)
    elsif(attributes['color_capture'] > 0 && character =~ /[0-9,A-F,a-f]/)
      capture_color(character, new_text, attributes)
    elsif(attributes['palette_capture'] > 0 && character =~ /[0-9,A-F,a-f]/)
      capture_palette_color(character, new_text, attributes)
    elsif(attributes['unicode_capture'] == 1 && character == '+') # Skip
      return
    elsif(attributes['unicode_capture'] > 0 && character =~ /[0-9,A-F,a-f]/)
      capture_unicode(character, new_text, attributes)
    elsif(attributes['pipe'] == true &&
        attributes['repeat_pattern'] == false &&
        attributes['pattern_escape'] == true)
      process_escaped_character(character, new_text, attributes)
    elsif(character == '&' && attributes['ampersand_mode'] == true &&
        attributes['pipe'] == false)
      process_ampersand(character, new_text, attributes)
    elsif(attributes['pipe'] == true)
      process_piped_character(character, new_text, attributes)
    elsif(attributes['ampersand'] == true)
      process_ampersanded_character(character, new_text, attributes)
    elsif(attributes['box'] == 0)
      new_text << process_box_zero_replace(character)
    elsif(attributes['box'] == 1)
      new_text << process_box_one_replace(character)
    elsif(attributes['box'] == 2)
      new_text << process_box_two_replace(character)
    else
      new_text << character
    end
  end

  def emit_color(new_text, attributes)
    r = attributes['r'].to_i(16).to_s
    g = attributes['g'].to_i(16).to_s
    b = attributes['b'].to_i(16).to_s
    if(attributes['ampersand'] == true)        # Background Color
      new_text << "\e[48;2;#{r};#{g};#{b}m"
      attributes['ampersand'] = false
    else                                       # Foreground Color
      new_text << "\e[38;2;#{r};#{g};#{b}m"
    end
    attributes['color_capture'] = 0
    attributes['r'] = String.new
    attributes['g'] = String.new
    attributes['b'] = String.new
  end

  def emit_palette_color(new_text, attributes)
    p = attributes['p'].to_i(16).to_s
    if(attributes['ampersand'] == true)        # Background Color
      new_text << "\e[48;5;#{p}m"
      attributes['ampersand'] = false
    else                                       # Foreground Color
      new_text << "\e[38;5;#{p}m"
    end
    attributes['palette_capture'] = 0
    attributes['p'] = String.new
  end

  def emit_unicode(new_text, attributes)
    new_text << [attributes['unicode'].to_i(16)].pack('U*')
    attributes['unicode_capture'] = 0
    attributes['unicode'] = String.new
  end

  def process_pipe(character, new_text, attributes)
    if(attributes['pipe'] == true && attributes['num'] == 0)      # ||
      attributes['pipe'] = false
      new_text << character
    else
      attributes['pipe'] = true
    end
  end

  def process_repeat_pattern(character, new_text, attributes)
    if(attributes['repeat_pattern'] == true)  # ~ at end of |5~Repeat 5 times~
      attributes['num'].times do
        new_text << pipetext(attributes['pattern'], attributes['box_mode'],
            attributes['ampersand_mode'])
      end
      attributes['num'] = 0
      attributes['pipe'] = false
      attributes['pattern_escape'] = false
      attributes['repeat_pattern'] = false
      attributes['pattern'] = String.new
    else                                # ~ after number in |5~Repeat 5 times~
      attributes['repeat_pattern'] = true
    end
  end

  def escape_fix(text)
    text.gsub(/\\a/, "\a").gsub(/\\b/, "\b").gsub(/\\e/, "\e")
        .gsub(/\\f/, "\f").gsub(/\\n/, "\n").gsub(/\\r/, "\r")
        .gsub(/\\t/, "\t").gsub(/\\v/, "\v").gsub(/\\~/, '~')
  end

  def process_escaped_character(character, new_text, attributes)
    if(attributes['num'] > 0)
      attributes['num'].times do
        new_text << escape_fix("\\#{character}")
      end
    else
      new_text << escape_fix("\\#{character}")
    end
    attributes['num'] = 0
    attributes['pipe'] = false
    attributes['pattern_escape'] = false
    attributes['pattern'] = String.new
    attributes['repeat_pattern'] = false
  end

  def capture_color(character, new_text, attributes)
    if(character =~ /[0-9,A-F,a-f]/)
      if(attributes['color_capture'] <= 2)
        attributes['r'] << character
      elsif(attributes['color_capture'] <= 4)
        attributes['g'] << character
      elsif(attributes['color_capture'] <= 6)
        attributes['b'] << character
      end
      if(attributes['color_capture'] == 6)
        emit_color(new_text, attributes)
      else
        attributes['color_capture'] += 1
      end
    end
  end

  def capture_character_pattern(character, attributes)
    if(character == '\\')
      attributes['pattern_escape'] = true
    else
      if(attributes['pattern_escape'] == true)
        attributes['pattern'] << "\\#{character}"
        attributes['pattern_escape'] = false
      else
        attributes['pattern'] << character
      end
    end
  end

  def capture_palette_color(character, new_text, attributes)
    if(character =~ /[0-9,A-F,a-f]/)
      if(attributes['palette_capture'] <= 2)
        attributes['p'] << character
      end
      if(attributes['palette_capture'] == 2)
        emit_palette_color(new_text, attributes)
      else
        attributes['palette_capture'] += 1
      end
    end
  end

  def capture_unicode(character, new_text, attributes)
    if(character =~ /[0-9,A-F,a-f]/)
      if(attributes['unicode_capture'] <= 6)
        attributes['unicode'] << character
      end
      if(attributes['unicode_capture'] == 6)
        emit_unicode(new_text, attributes)
      else
        attributes['unicode_capture'] += 1
      end
    end
  end

  def process_ampersand(character, new_text, attributes)
    if(attributes['ampersand'] == true)         # &&
      attributes['ampersand'] = false
      new_text << character
    else
      attributes['ampersand'] = true
    end
  end

  def update_attributes(new_text, attributes)
    if(attributes['bold'] == true)
      new_text << "\e[1m"
    end
    if(attributes['faint'] == true)
      new_text << "\e[2m"
    end
    if(attributes['italic'] == true)
      new_text << "\e[3m"
    end
    if(attributes['underline'] == true)
      new_text << "\e[4m"
    end
    if(attributes['blink'] == true)
      new_text << "\e[5m"
    end
    if(attributes['inverse'] == true)
      new_text << "\e[7m"
    end
    if(attributes['crossed_out'] == true)
      new_text << "\e[9m"
    end
  end

  def process_piped_character(character, new_text, attributes)
    attributes['found'] = true                  # Assume we will find the next character
    if(attributes['num'] == 0)                  # We are not in repeat character mode
      case character
      when '&'                                  # |&       - Toggle & on/off for Background Colors
        if(attributes['ampersand_mode'] == true)
          attributes['ampersand_mode'] = false
        else
          attributes['ampersand_mode'] = true
        end
        attributes['pipe'] = false
      when '!'                                  # |!       - Clear screen
        new_text << "\e[H\e[J"
      when '+'                                  # |+       - Bold
        if(attributes['bold'] == false)
          new_text << "\e[1m"
          attributes['bold'] = true
        else
          new_text << "\e[22m"
          attributes['bold'] = false
        end
      when '.'                                  # |.       - Faint / Dim
        if(attributes['faint'] == false)
          new_text << "\e[2m"
          attributes['faint'] = true
        else
          new_text << "\e[22m"
          attributes['faint'] = false
        end
      when '~'                                  # |~       - Italic
        if(attributes['italic'] == false)
          new_text << "\e[3m"
          attributes['italic'] = true
        else
          new_text << "\e[23m"
          attributes['italic'] = false
        end
      when '_'                                  # |_       - Underline
        if(attributes['underline'] == false)
          new_text << "\e[4m"
          attributes['underline'] = true
        else
          new_text << "\e[24m"
          attributes['underline'] = false
        end
      when '@'                                  # |@       - Blink
        if(attributes['blink'] == false)
          new_text << "\e[5m"
          attributes['blink'] = true
        else
          new_text << "\e[25m"
          attributes['blink'] = false
        end
      when 'i', 'I'                             # |i       - Inverse
        if(attributes['inverse'] == false)
          new_text << "\e[7m"
          attributes['inverse'] = true
        else
          new_text << "\e[27m"
          attributes['inverse'] = false
        end
      when 'x', 'X'                             # |x       - Crossed Out
        if(attributes['crossed_out'] == false)
          new_text << "\e[9m"
          attributes['crossed_out'] = true
        else
          new_text << "\e[29m"
          attributes['crossed_out'] = false
        end
      when '#'                                  # |#RRGGBB
        attributes['color_capture'] = 1
      when 'P', 'p'                             # |P or |p - 2 character hex format color (256 colors)
        attributes['palette_capture'] = 1
      when 'U', 'u'                             # |U or |u - Unicode 6 character hex format
        attributes['unicode_capture'] = 1
      when 'K', 'k'                             # |K or |k - Foreground text black
        attributes['fg'] = "\e[30m"
        new_text << "\e[0;30m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'S', 's'                             # |S or |s - Foreground text smoke
        attributes['fg'] = "\e[1;30m"
        new_text << "\e[1;30m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        attributes['bold'] = true
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'r'                                  # |r       - Foreground text red
        attributes['fg'] = "\e[31m"
        new_text << "\e[0;31m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'R'                                  # |R       - Foreground text bright red
        attributes['fg'] = "\e[1;31m"
        new_text << "\e[1;31m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        attributes['bold'] = true
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'g'                                  # |g       - Foreground text green
        attributes['fg'] = "\e[32m"
        new_text << "\e[0;32m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'G'                                  # |G       - Foreground text bright green
        attributes['fg'] = "\e[1;32m"
        new_text << "\e[1;32m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        attributes['bold'] = true
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'y'                                  # |y       - Foreground text yellow (brown)
        attributes['fg'] = "\e[33m"
        new_text << "\e[0;33m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'Y'                                  # |Y       - Foreground text bright yellow
        attributes['fg'] = "\e[1;33m"
        new_text << "\e[1;33m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        attributes['bold'] = true
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'b'                                  # |b       - Foreground text blue
        attributes['fg'] = "\e[34m"
        new_text << "\e[0;34m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'B'                                  # |B       - Foreground text bright blue
        attributes['fg'] = "\e[1;34m"
        new_text << "\e[1;34m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        attributes['bold'] = true
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'm'                                  # |m       - Foreground text magenta
        attributes['fg'] = "\e[35m"
        new_text << "\e[0;35m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'M'                                  # |M       - Foreground text bright magenta
        attributes['fg'] = "\e[1;35m"
        new_text << "\e[1;35m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        attributes['bold'] = true
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'c'                                  # |c       - Foreground text cyan
        attributes['fg'] = "\e[36m"
        new_text << "\e[0;36m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'C'                                  # |C       - Foreground text bright cyan
        attributes['fg'] = "\e[1;36m"
        new_text << "\e[1;36m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        attributes['bold'] = true
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'W', 'w'                             # |W or |w - Foreground text white
        attributes['fg'] = "\e[1;37m"
        new_text << "\e[1;37m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        attributes['bold'] = true
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'N', 'n'                             # |N or |n - Foreground text normal
        attributes['fg'] = ""
        new_text << "\e[0;37m"
        attributes['bold'] = false
        update_attributes(new_text, attributes)
        new_text << attributes['bg'] == "\e[0m" ? "" : attributes['bg']
      when 'O'                                  # |O - Box mode off
        attributes['box'] = -1
      when 'o'                                  # |o - Box mode 0
        attributes['box'] = 0
      when '-'                                  # |- - Box mode 1
        if(attributes['box_mode'] == true)
          attributes['box'] = 1
        else                                    # We didn't find the next character
          attributes['found'] = false
        end
      when '='                                  # |= - Box mode 2
        if(attributes['box_mode'] == true)
          attributes['box'] = 2
        else                                    # We didn't find the next character
          attributes['found'] = false
        end
      when '\\'                                 # |\       - Escape mode
        attributes['pattern_escape'] = true
      else                                      # We didn't find the next character
        attributes['found'] = false
      end
    elsif(character == '\\')
      attributes['pattern_escape'] = true
    else                                        # We didn't find the next character
      attributes['found'] = false
    end
    if(attributes['found'] == false)
      if(character == '0')                      # |10+
        if(attributes['num'] > 0)
          attributes['num'] *= 10
        end
      elsif(character >= '1' && character <= '9')  # |1+ through |9+
        if(attributes['num'] > 0)
          attributes['num'] *= 10
        end
        attributes['num'] += character.to_i
      else
        if(attributes['num'] <= 0)              # No replacement found
          new_text << '|' + character
        else                                    # Repeat number replacement found
          if(attributes['box'] == 1)
            attributes['num'].times do
              new_text << process_box_one_replace(character)
            end
          elsif(attributes['box'] == 2)
            attributes['num'].times do
              new_text << process_box_two_replace(character)
            end
          else
            attributes['num'].times do
              new_text << character
            end
          end
          attributes['num'] = 0
        end
        attributes['pipe'] = false
      end
    elsif(attributes['pattern_escape'] == false)
      attributes['pipe'] = false
    end
  end

  def process_ampersanded_character(character, new_text, attributes)
    case character
    when '#'                                    # &#RRGGBB
      attributes['color_capture'] = 1
      return
    when 'P', 'p'                               # |P or |p - 2 character hex format color (256 colors)
      attributes['palette_capture'] = 1
      return
    when 'W', 'w'                               # &W or &w - Background white
      new_text << "\e[0;47m"
      attributes['bg'] = "\e[47m"
      update_attributes(new_text, attributes)
      new_text << attributes['fg'] == "\e[0m" ? "" : attributes['fg']
    when 'C', 'c'                               # &C or &c - Background cyan
      new_text << "\e[0;46m"
      attributes['bg'] = "\e[46m"
      update_attributes(new_text, attributes)
      new_text << attributes['fg'] == "\e[0m" ? "" : attributes['fg']
    when 'M', 'm'                               # &M or &m - Background magenta
      new_text << "\e[0;45m"
      attributes['bg'] = "\e[45m"
      update_attributes(new_text, attributes)
      new_text << attributes['fg'] == "\e[0m" ? "" : attributes['fg']
    when 'B', 'b'                               # &B or &b - Background blue
      new_text << "\e[0;44m"
      attributes['bg'] = "\e[44m"
      update_attributes(new_text, attributes)
      new_text << attributes['fg'] == "\e[0m" ? "" : attributes['fg']
    when 'Y', 'y'                               # &Y or &y - Background yellow (brown)
      new_text << "\e[0;43m"
      attributes['bg'] = "\e[43m"
      update_attributes(new_text, attributes)
      new_text << attributes['fg'] == "\e[0m" ? "" : attributes['fg']
    when 'G', 'g'                               # &G or &g - Background green
      new_text << "\e[0;42m"
      attributes['bg'] = "\e[42m"
      update_attributes(new_text, attributes)
      new_text << attributes['fg'] == "\e[0m" ? "" : attributes['fg']
    when 'R', 'r'                               # &R or &r - Background red
      new_text << "\e[0;41m"
      attributes['bg'] ="\e[41m"
      update_attributes(new_text, attributes)
      new_text << attributes['fg'] == "\e[0m" ? "" : attributes['fg']
    when 'S', 's', 'K', 'k'                     # &S, &s, &K, &k - Background black/smoke
      new_text << "\e[0;40m"
      attributes['bg'] = "\e[40m"
      update_attributes(new_text, attributes)
      new_text << attributes['fg'] == "\e[0m" ? "" : attributes['fg']
    when 'N', 'n'                               # &N or &n - Background normal
      new_text << "\e[0m"
      attributes['bg'] = ""
      update_attributes(new_text, attributes)
      new_text << attributes['fg'] == "\e[0m" ? "" : attributes['fg']
    else
      new_text << '&' + character
    end
    attributes['ampersand'] = false
  end

  def process_box_zero_replace(character)
    case character
    when '['
      '+'
    when ']'
      '+'
    when '-'
      '-'
    when '!'
      '|'
    when '>'
      '+'
    when '<'
      '+'
    when '+'
      '+'
    when '{'
      '+'
    when '}'
      '+'
    when 'v'
      '+'
    when '^'
      '+'
    else
      character
    end
  end

  def process_box_one_replace(character)
    case character
    when '['
      '┌'
    when ']'
      '┐'
    when '-'
      '─'
    when '!'
      '│'
    when '>'
      '├'
    when '<'
      '┤'
    when '+'
      '┼'
    when '{'
      '└'
    when '}'
      '┘'
    when 'v'
      '┬'
    when '^'
      '┴'
    else
      character
    end
  end

  def process_box_two_replace(character)
    case character
    when '['
      '╔'
    when ']'
      '╗'
    when '-'
      '═'
    when '!'
      '║'
    when '>'
      '╠'
    when '<'
      '╣'
    when '+'
      '╬'
    when '{'
      '╚'
    when '}'
      '╝'
    when 'v'
      '╦'
    when '^'
      '╩'
    else
      character
    end
  end
end
