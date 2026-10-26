require "io/console"

module PipeText

  public

  def pipetext_init(box_mode=true, ampersand_mode=false)
    attributes = {
      "pipe"             => false,          # Pipe already been found?
      "repeat_pattern"   => false,          # Used by |<#>~repeat pattern~
      "pattern"          => String.new,     # Used by |<#>~repeat pattern~ to capture
      "escape"           => false,          # Has an escape \ already been found in front of this character?
      "ampersand"        => false,          # Has an ampersand already been found in front of this character?
      "ampersand_mode"   => ampersand_mode, # Do we even process ampersands for background colors?
      "blink"            => false,          # Is blink turned on?
      "bold"             => false,
      "crossed_out"      => false,
      "faint"            => false,
      "found"            => false,          # At the end -- did we find a match?
      "italic"           => false,
      "inverse"          => false,
      "underline"        => false,
      "box"              => -1,             # Default to |O (no boxes)
      "box_mode"         => box_mode,
      "box_capture"      => 0,              # Used to capture boxes for update or to display
      "boxes"            => 0,              # Total number of boxes used for nesting
      "box_attributes"   => Hash.new,       # Box variables captured
      "num"              => 0,              # Number of times to repeat pattern
      "end_capture"      => false,          # Used to capture the end column number
      "end"              => 0,              # Number which current denotes the end of the column
      "position"         => 0,              # Number which current position in the column
      "center_capture"   => false,          # Used to capture text for centering
      "center"           => String.new,     # Text to be centered
      "right_capture"    => false,          # Used to capture text for right justify
      "right"            => String.new,     # Text to be justified to the right
      "variable_capture" => false,          # Used to capture a variable for update or to display
      "variable"         => String.new,     # Variable captured
      "variables"        => Hash.new,       # Stores all captured variables
      "emoji_capture"    => false,          # Used to capture emoji description or bell/move to position
      "emoji"            => String.new,     # Used to capture emoji description or bell/move to position
      "unicode_capture"  => 0,              # Used to capture Unicode using 6 character UTF-16 hex format
      "unicode"          => String.new,
      "palette_capture"  => 0,              # Used to capture 8-bit color using 2 character hex format
      "p"                => String.new,     # |p00 to |pFF
      "color_capture"    => 0,              # Used to capture RGB color using #RRGGBB format
      "r"                => String.new,
      "g"                => String.new,
      "b"                => String.new,
      "fg"               => String.new,     # Needed to restore after background change
      "bg"               => String.new,     # Needed to restore after foreground change
      "remap"            => Hash.new,       # Used to remap pipetext codes
      "shell_prompt"     => false           # Used to add \[ and \] around non-printables for prompts
    }
    attributes["variables"]["height"], attributes["variables"]["width"] = IO.console.winsize
    return attributes
  end

  def pipe(text, attributes)
    new_text = String.new
    if(text != "")
      if(attributes["remap"] != {})
        attributes["remap"].each do |old, new|
          text.gsub!(old, new)
        end
      end
      attributes["remap"] = Hash.new
      text.chars.each do |character|
        process_character(character, new_text, attributes)
        if(new_text =~ /.*\n(.*)$/m)
          attributes["position"] = printable_length($1)
        else
          attributes["position"] = printable_length(new_text)
        end
      end
    end
    # Clean up in case we've captured something we didn't process yet
    if(attributes["color_capture"] > 0)
      emit_color(new_text, attributes)
    elsif(attributes["palette_capture"] > 0)
      emit_palette_color(new_text, attributes)
    elsif(attributes["unicode_capture"] > 0)
      emit_unicode(new_text, attributes)
    elsif(attributes["emoji_capture"] == true)
      new_text << "|[" + attributes["emoji"]
    elsif(attributes["center_capture"] == true)
      new_text << "|{" + attributes["center"]
    elsif(attributes["right_capture"] == true)
      emit_right(new_text, attributes)
    elsif(attributes["variable_capture"] == true)
      new_text << "|(" + attributes["variable"]
    end
    return new_text
  end

  def pipetext(text, box_mode=true, ampersand_mode=false)
    pipe(text, pipetext_init(box_mode, ampersand_mode))
  end

  # Immediate output to screen, no string buffer
  def fastpipe(text, attributes)
    new_text = String.new
    text.chars.each do |character|
      process_character(character, new_text, attributes)
      if(new_text != "")
        print(new_text)
        if(new_text =~ /.*\n(.*)$/m)
          attributes["position"] = printable_length($1)
        else
          attributes["position"] += printable_length(new_text)
        end
        new_text = String.new
      end
    end
    # Clean up in case we've captured something we didn't process yet
    if(attributes["color_capture"] > 0)
      emit_color(new_text, attributes)
    elsif(attributes["palette_capture"] > 0)
      emit_palette_color(new_text, attributes)
    elsif(attributes["unicode_capture"] > 0)
      emit_unicode(new_text, attributes)
    elsif(attributes["emoji_capture"] == true)
      new_text << "|[" + attributes["emoji"]
    elsif(attributes["center_capture"] == true)
      new_text << "|{" + attributes["center"]
    elsif(attributes["right_capture"] == true)
      emit_right(new_text, attributes)
    elsif(attributes["variable_capture"] == true)
      new_text << "|(" + attributes["variable"]
    end
    print(new_text)
  end

  def fastpipetext(text, box_mode=true, ampersand_mode=false)
    fastpipe(text, pipetext_init(box_mode, ampersand_mode))
  end

  def write(text, box_mode=true, ampersand_mode=false)
    fastpipetext(text, box_mode, ampersand_mode)
  end

  # Defaults to using & for background colors
  def paint(text, box_mode=true, ampersand_mode=true)
    fastpipetext(text, box_mode, ampersand_mode)
  end

  def ignored_character(character, ignored_characters)
    ignored_characters.chars.each do |ignored|
      if(character == ignored)
        return true
      end
    end
    return false
  end

  # Match abbreviated text descriptions for emojis by default ignore case and punctuation
  # Allows for "space anchoring" so you can use |[smi f w he e] as an abbreviation for
  # |[smiling face with heart-eyes]
  def abbreviated_match(input, match, case_match=false, ignored_characters=",.,:-")
    if(!input || !match)
      return 0
    end
    count = 0
    offset = 0
    input.chars.each_with_index do |character, index|
      while(ignored_character(match[index + offset], ignored_characters))
        offset += 1
      end
      if(character == match[index + offset].chr)
        count += 1
      elsif(case_match == false && character.downcase == match[index + offset].chr.downcase)
        count += 1
      elsif(character == " " && match[index + offset..-1] =~ / /)
        count += 1
        while(match[index + offset].chr != character)
          offset += 1
        end
      else
        count = 0
        offset = 0
        break
      end  
    end  
    return count + offset
  end

  # Just yikes!
  def double_wide_character(character)
    if(character == nil || character == "")
      return false
    end
    ord = character.ord
    if((ord >= 4352 && ord <= 4447) ||
        (ord >= 4520 && ord <= 4607) ||
        ord == 8986 || ord == 8987 ||
        ord == 9193 || ord == 9194 ||
        ord == 9195 || ord == 9196 ||
        ord == 9200 ||
        ord == 9203 ||
        ord == 9654 ||
        ord == 9664 ||
        ord == 9726 ||
        ord == 9729 || ord == 9730 ||
        ord == 9731 || ord == 9732 ||
        ord == 9742 ||
        ord == 9748 || ord == 9749 ||
        ord == 9752 ||
        ord == 9757 ||
        ord == 9760 ||
        ord == 9762 || ord == 9763 ||
        ord == 9770 ||
        ord == 9774 || ord == 9775 ||
        ord == 9784 ||
        (ord >= 9800 && ord <= 9811) ||
        ord == 9823 ||
        ord == 9832 ||
        ord == 9851 ||
        ord == 9855 ||
        ord == 9874 ||
        ord == 9875 || ord == 9876 ||
        ord == 9877 ||
        ord == 9878 || ord == 9879 ||
        ord == 9884 ||
        ord == 9888 || ord == 9889 ||
        ord == 9895 ||
        ord == 9904 || ord == 9905 ||
        ord == 9917 || ord == 9918 ||
        ord == 9924 || ord == 9925 ||
        ord == 9928 ||
        ord == 9934 || ord == 9935 ||
        ord == 9937 ||
        ord == 9939 || ord == 9940 ||
        ord == 9961 || ord == 9962 ||
        ord == 9968 || ord == 9969 ||
        ord == 9970 || ord == 9971 ||
        ord == 9972 || ord == 9973 ||
        ord == 9975 || ord == 9976 ||
        ord == 9977 || ord == 9978 ||
        ord == 9981 ||
        ord == 9989 ||
        ord == 9993 || ord == 9994 ||
        ord == 9995 || ord == 9996 ||
        ord == 9997 ||
        ord == 9999 ||
        ord == 10002 ||
        ord == 10024 ||
        ord == 10060 ||
        ord == 10062 ||
        ord == 10067 || ord == 10068 ||
        ord == 10069 ||
        ord == 10071 ||
        ord == 10083 ||
        ord == 10133 || ord == 10134 ||
        ord == 10135 ||
        ord == 10160 ||
        ord == 10175 ||
        ord == 10548 ||
        ord == 10549 ||
        ord == 11035 ||
        ord == 11036 ||
        ord == 11088 ||
        ord == 11093 ||
        (ord >= 11904 && ord <= 12245) ||
        (ord >= 12272 && ord <= 12283) ||
        (ord >= 12288 && ord <= 12351) ||
        (ord >= 12352 && ord <= 12735) ||
        (ord >= 12736 && ord <= 12771) ||
        (ord >= 12784 && ord <= 12831) ||
        (ord >= 12832 && ord <= 12879) ||
        (ord >= 12880 && ord <= 13055) ||
        (ord >= 13056 && ord <= 13311) ||
        (ord >= 13312 && ord <= 19903) ||
        (ord >= 19968 && ord <= 40959) ||
        (ord >= 44032 && ord <= 55203) ||
        (ord >= 63744 && ord <= 64255) ||
        (ord >= 65072 && ord <= 65103) ||
        (ord >= 65104 && ord <= 65135) ||
        (ord >= 65184 && ord <= 65279) ||
        (ord >= 65280 && ord <= 65376) ||
        (ord >= 65382 && ord <= 65439) ||
        (ord >= 65440 && ord <= 65500) ||
        (ord >= 65504 && ord <= 65510) ||
        (ord >= 65512 && ord <= 65518) ||
        (ord >= 110592 && ord <= 110593) ||
        (ord >= 110594 && ord <= 110847) ||
        ord == 126980 ||
        ord == 127183 ||
        ord == 127374 ||
        ord == 127377 || ord == 127378 ||
        ord == 127379 ||
        ord == 127381 || ord == 127382 ||
        ord == 127383 ||
        (ord >= 127462 && ord <= 127487) ||
        (ord >= 127744 && ord <= 129791) ||
        (ord >= 131072 && ord <= 173791) ||
        (ord >= 173824 && ord <= 177983) ||
        (ord >= 177984 && ord <= 178207) ||
        (ord >= 178208 && ord <= 183983) ||
        (ord >= 183984 && ord <= 191455) ||
        (ord >= 191456 && ord <= 196607) ||
        (ord >= 196608 && ord <= 201546) ||
        (ord >= 201552 && ord <= 262143))
      return true
    end
    return false
  end

  # This is not entirely accurate because of emojis - double yikes!
  def printable_length(string)
    if(string == "")
      return 0
    end
    length = 0
    escape = false
    wide = false
    wide_count = 0
    zero_width_join = false
    last_was_wide = false
    country_code = false
    string.chars.each do |character|
      if(character[0].ord == 27)
        escape = true
      elsif(character[0].ord == 226 && wide == false)
        wide = true
      elsif(character[0].ord == 240 && wide == false)
        wide = true
      elsif(character[0].ord >= 32)
        if(escape == true && character[0].ord == 109)
          escape = false
        elsif(zero_width_join == true)
          zero_width_join = false
        elsif(character[0].ord == 8205)
          zero_width_join = true
        elsif(character[0].ord == 65039)
          if(last_was_wide == false)
            length += 1
          end
        elsif(character[0].ord == 8419)
          next
        elsif(character[0].ord >= 127462 && character[0].ord <= 127487 && country_code == true)
          country_code = false
          next
        elsif(character[0].ord >= 127995 && character[0].ord <= 127999)
          next
        elsif(character[0].ord >= 917602 && character[0].ord <= 917631)
          next
        elsif(double_wide_character(character))
          if(character[0].ord >= 127462 && character[0].ord <= 127487)
            country_code = true
          end
          length += 2
          last_was_wide = true
        elsif(escape == false && wide == false)
          length += 1
          last_was_wide = false
          country_code = false
        elsif(wide == true)
          wide_count += 1
        end
        if(wide == true && wide_count >= 2)
          if(character[0].ord == 147)
            length += 1
          else
            length += 1
            wide = false
            wide_count = 0
          end
        end
      end
    end
    if(wide == true && wide_count > 0)
      length += 1
    end
    return length
  end

  def with_spinner(spinner="⠇⠏⠋⠙⠹⠸⣰⣠⣄⣆", colors=["|n"])
    spinner_thread = Thread.new do
      count = 0
      if(colors == nil)
        fastpipetext("|h#{spinner[0]}")
      else
        fastpipetext("|h#{colors[0]}#{spinner[0]}")
      end
      while(true)
        ord = spinner[count % spinner.length].ord
        if(double_wide_character(spinner[count % spinner.length]))
          print "\b"
        end
        count += 1
        sleep 0.05
        if(colors == nil)
          fastpipetext("\b#{spinner[count % spinner.length]}")
        else
          fastpipetext("\b#{colors[count % colors.length]}#{spinner[count % spinner.length]}")
        end
      end
    end
    begin
      yield
    ensure
      spinner_thread.kill
      fastpipetext("|H\b|n")
    end
  end

  def with_spinner_mode(mode=0, &block)
    if(mode == 0)
      with_spinner(&block)
    elsif(mode == 1)
      with_spinner(["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘",
                    "🌑", "🌘", "🌗", "🌖", "🌕", "🌔", "🌓", "🌒"], &block)
    elsif(mode == 2)
      with_spinner(["🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛"], &block)
    elsif(mode == 3)
      with_spinner(["◐", "◓", "◑", "◒"], &block)
    elsif(mode == 4)
      with_spinner(["◜", "◠", "◝", "◞", "◡", "◟"], &block)
    elsif(mode == 5)
      with_spinner(["⠁", "⠂", "⠄", "⠂"], &block)
    elsif(mode == 6)
      with_spinner([" ", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃"], &block)
    elsif(mode == 7)
      with_spinner(["◰", "◳", "◲", "◱"], &block)
    elsif(mode == 8)
      with_spinner(["🔴", "🟠", "🟡", "🟢", "🔵", "🟣"], &block)
    end
  end

  private

  def process_character(character, new_text, attributes)
    if(attributes["repeat_pattern"] == false)
      # Will still need to process character, first process incorrect formats
      if(attributes["color_capture"] > 0 && character !~ /[0-9,A-F,a-f]/)
        emit_color(new_text, attributes)
      elsif(attributes["palette_capture"] > 0 && character !~ /[0-9,A-F,a-f]/)
        emit_palette_color(new_text, attributes)
      elsif(attributes["unicode_capture"] > 0 && (character !~ /[0-9,A-F,a-f,+]/ ||
          (attributes["unicode_capture"] != 1 && character == "+")))
        emit_unicode(new_text, attributes)
      end
    end
    if(attributes["end_capture"] == true && character !~ /[0-9]/)
      attributes["end"] = attributes["num"]
      attributes["num"] = 0
      attributes["end_capture"] = false
    end
    if(attributes["end_capture"] == true && character =~ /[0-9]/)
      if(character == "0")				# |10+
        if(attributes["num"] > 0)
          attributes["num"] *= 10
        end
      elsif(character >= "1" && character <= "9")	# |1+ through |9+
        if(attributes["num"] > 0)
          attributes["num"] *= 10
        end
        attributes["num"] += character.to_i
      end
    elsif(character == ")" && attributes["variable_capture"] == true && attributes["escape"] == false)
      if(attributes["variable"] =~ /=/ && attributes["variable"][0] != "#")	# Update
        update_variable(attributes)
      else									# Display
        emit_variable(new_text, attributes)
      end
    elsif(attributes["variable_capture"] == true)
      if(character == "\\")
        attributes["escape"] = true
      else
        if(attributes["escape"] == true)
          attributes["variable"] << "\\#{character}"
          attributes["escape"] = false
        else
          attributes["variable"] << character
        end
      end
    elsif(attributes["center_capture"] == true)
      if(character == "\\")
        attributes["escape"] = true
      else
        if(attributes["escape"] == true)
          attributes["center"] << "\\#{character}"
          attributes["escape"] = false
        elsif(character == "}")
          emit_center(new_text, attributes)
        else
          attributes["center"] << character
        end
      end
    elsif(attributes["right_capture"] == true)
      if(character == "\\")
        attributes["escape"] = true
      else
        if(attributes["escape"] == true)
          attributes["right"] << "\\#{character}"
          attributes["escape"] = false
          if(character == "n")
            emit_right(new_text, attributes)
          end
        elsif(character == "\n")
          emit_right(new_text, attributes)
        else
          attributes["right"] << character
        end
      end
    elsif(attributes["box_capture"] > 0)
      if(attributes["box_attributes"][attributes["box_capture"]]["capture_attributes"] == true)
        if(character == "]" && !open_expression(attributes["box_attributes"][attributes["box_capture"]]["attributes"]))
          attributes["box_attributes"][attributes["box_capture"]]["capture_attributes"] = false
        else
          attributes["box_attributes"][attributes["box_capture"]]["attributes"] << character
        end
      elsif(character == "]" && (attributes["box_attributes"][attributes["box_capture"]]["capture"] =~ /\|\[\/box$/i ||
          attributes["box_attributes"][attributes["box_capture"]]["capture"] =~ /\|\[box end$/i))
        attributes["box_attributes"][attributes["box_capture"]]["capture"].sub!(/\|\[box end$/i, "")
        attributes["box_attributes"][attributes["box_capture"]]["capture"].sub!(/\|\[\/box$/i, "")
        if(attributes["box_attributes"][attributes["box_capture"]]["parent"] == 0)
          emit_box(new_text, attributes)
        else
          attributes["box_capture"] = attributes["box_attributes"][attributes["box_capture"]]["parent"]
        end
       	# Start another box
      elsif(character == "]" && attributes["box_attributes"][attributes["box_capture"]]["capture"] !~ /\|\[boxi/i &&
          attributes["box_attributes"][attributes["box_capture"]]["capture"] =~ /\|\[box(.*)?/mi)
        capture_attributes = $1
        parent = attributes["box_capture"]
        attributes["box_attributes"][parent]["capture"].sub!(/\|\[box#{Regexp.escape(capture_attributes)}$/i, "")
        attributes["boxes"] += 1
        attributes["box_capture"] = attributes["boxes"]
        attributes["box_attributes"][attributes["box_capture"]] = Hash.new
        attributes["box_attributes"][attributes["box_capture"]]["parent"] = parent
        attributes["box_attributes"][attributes["box_capture"]]["capture_attributes"] = false
        attributes["box_attributes"][attributes["box_capture"]]["attributes"] = capture_attributes.lstrip
        attributes["box_attributes"][attributes["box_capture"]]["capture"] = String.new
      else
        attributes["box_attributes"][attributes["box_capture"]]["capture"] << character
      end
    elsif(attributes["emoji_capture"] == true)
      if(character == "]")
        if(attributes["emoji"] =~ /^b$/)
          new_text << "\a"
          attributes["emoji"] = String.new
          attributes["emoji_capture"] = false
        elsif(attributes["emoji"] =~ /^([0-9]+)[,;]([0-9]+)$/)
          if(attributes["shell_prompt"] == true)
            new_text << "\\[\e[#{$1};#{$2}H\\]"
          else
            new_text << "\e[#{$1};#{$2}H"
          end
          attributes["emoji"] = String.new
          attributes["emoji_capture"] = false
        elsif(attributes["emoji"] =~ /^([0-9]+)s$/i)   # Sleep in seconds
          attributes["emoji"] = String.new
          attributes["emoji_capture"] = false
          sleep($1.to_i)
        elsif(attributes["emoji"] =~ /^([0-9]+)ms$/i)  # Sleep in milliseconds
          attributes["emoji"] = String.new
          attributes["emoji_capture"] = false
          sleep($1.to_i / 1000.0)
        elsif(attributes["emoji"] + character =~ /^box\]/i)	# Box start
          attributes["emoji"] = String.new
          attributes["emoji_capture"] = false
          attributes["box_capture"] = 1
          attributes["boxes"] = 1
          attributes["box_attributes"][attributes["box_capture"]] = Hash.new
          attributes["box_attributes"][attributes["box_capture"]]["parent"] = 0
          attributes["box_attributes"][attributes["box_capture"]]["capture_attributes"] = false
          attributes["box_attributes"][attributes["box_capture"]]["attributes"] = String.new
          attributes["box_attributes"][attributes["box_capture"]]["capture"] = String.new
        else
          emit_emoji(new_text, attributes)
        end
      elsif(attributes["emoji"] + character =~ /^box /i)	# Box start with attributes
        attributes["emoji"] = String.new
        attributes["emoji_capture"] = false
        attributes["box_capture"] += 1
        attributes["boxes"] += 1
        attributes["box_attributes"][attributes["box_capture"]] = Hash.new
        attributes["box_attributes"][attributes["box_capture"]]["parent"] = 0
        attributes["box_attributes"][attributes["box_capture"]]["capture_attributes"] = true
        attributes["box_attributes"][attributes["box_capture"]]["attributes"] = String.new
        attributes["box_attributes"][attributes["box_capture"]]["capture"] = String.new
      else
        attributes["emoji"] << character
      end
    elsif(character == "|" && attributes["repeat_pattern"] == false)
      process_pipe(character, new_text, attributes)
    elsif(character == "~" && attributes["pipe"] == true &&
        attributes["num"] > 0 && attributes["escape"] == false)
      process_repeat_pattern(character, new_text, attributes)
    elsif(attributes["repeat_pattern"] == true)
      capture_character_pattern(character, attributes)
    elsif(attributes["color_capture"] > 0 && character =~ /[0-9,A-F,a-f]/)
      capture_color(character, new_text, attributes)
    elsif(attributes["palette_capture"] > 0 && character =~ /[0-9,A-F,a-f]/)
      capture_palette_color(character, new_text, attributes)
    elsif(attributes["unicode_capture"] == 1 && character == "+") # Skip
      return
    elsif(attributes["unicode_capture"] > 0 && character =~ /[0-9,A-F,a-f]/)
      capture_unicode(character, new_text, attributes)
    elsif(attributes["pipe"] == true &&
        attributes["repeat_pattern"] == false &&
        attributes["escape"] == true)
      process_escaped_character(character, new_text, attributes)
    elsif(character == "&" && attributes["ampersand_mode"] == true &&
        attributes["pipe"] == false)
      process_ampersand(character, new_text, attributes)
    elsif(attributes["pipe"] == true)
      process_piped_character(character, new_text, attributes)
    elsif(attributes["ampersand"] == true)
      process_ampersanded_character(character, new_text, attributes)
    elsif(attributes["box"] == 0)
      new_text << process_box_zero_replace(character)
    elsif(attributes["box"] == 1)
      new_text << process_box_one_replace(character)
    elsif(attributes["box"] == 2)
      new_text << process_box_two_replace(character)
    else
      new_text << character
    end
  end

  def emit_color(new_text, attributes)
    r = attributes["r"].to_i(16).to_s
    g = attributes["g"].to_i(16).to_s
    b = attributes["b"].to_i(16).to_s
    if(attributes["ampersand"] == true)        # Background Color
      if(attributes["shell_prompt"] == true)
        new_text << "\\[\e[48;2;#{r};#{g};#{b}m\\]"
      else
        new_text << "\e[48;2;#{r};#{g};#{b}m"
      end
      attributes["bg"] = "\e[48;2;#{r};#{g};#{b}m"
      new_text << attributes["fg"] == "\e[0m" ? "" : attributes["fg"]
      attributes["ampersand"] = false
    else                                       # Foreground Color
      if(attributes["shell_prompt"] == true)
        new_text << "\\[\e[38;2;#{r};#{g};#{b}m\\]"
      else
        new_text << "\e[38;2;#{r};#{g};#{b}m"
      end
      attributes["fg"] = "\e[38;2;#{r};#{g};#{b}m"
      new_text << attributes["bg"] == "\e[0m" ? "" : attributes["bg"]
    end
    attributes["color_capture"] = 0
    attributes["r"] = String.new
    attributes["g"] = String.new
    attributes["b"] = String.new
  end

  def emit_palette_color(new_text, attributes)
    p = attributes["p"].to_i(16).to_s
    if(attributes["ampersand"] == true)        # Background Color
      if(attributes["shell_prompt"] == true)
        new_text << "\\[\e[48;5;#{p}m\\]"
      else
        new_text << "\e[48;5;#{p}m"
      end
      attributes["ampersand"] = false
    else                                       # Foreground Color
      if(attributes["shell_prompt"] == true)
        new_text << "\\[\e[38;5;#{p}m\\]"
      else
        new_text << "\e[38;5;#{p}m"
      end
    end
    attributes["palette_capture"] = 0
    attributes["p"] = String.new
  end

  def emit_unicode(new_text, attributes)
    new_text << [attributes["unicode"].to_i(16)].pack("U*")
    attributes["unicode_capture"] = 0
    attributes["unicode"] = String.new
  end

  def open_expression(text)
    if(text.count("\"") % 2 == 1)
      return true
    elsif(text.count("'") % 2 == 1)
      return true
    elsif(text.count("[") > text.count("]") + 1)
      return true
    end
    return false
  end

  def number?(text)
    text.chars.each do |character|
      if(character !~ /[0-9 ]/)
        return false
      end
    end
    return true
  end

  def update_variable(attributes)
    if(attributes["variable"] =~ /(.*)\-=(.*)/)
      if(!number?($2) || !number?(attributes["variables"][$1]))
        attributes["variables"][$1].slice!($2)
      elsif(attributes["variable"] =~ /(.*) \-= ?(.*)/ || attributes["variable"] =~ /(.*)\-= ?(.*)/)
        value = attributes["variables"][$1].to_i - $2.to_i
        attributes["variables"][$1] = value.to_s
      end
    elsif(attributes["variable"] =~ /(.*)\+=(.*)/)
      if(!number?($2) || !number?(attributes["variables"][$1]))
        attributes["variables"][$1] += $2
      elsif(attributes["variable"] =~ /(.*) \+= ?(.*)/ || attributes["variable"] =~ /(.*)\+= ?(.*)/)
        value = attributes["variables"][$1].to_i + $2.to_i
        attributes["variables"][$1] = value.to_s
      end
    elsif(attributes["variable"] =~ /(.*) \*= ?(.*)/ || attributes["variable"] =~ /(.*)\*= ?(.*)/)
      value = attributes["variables"][$1].to_i * $2.to_i
      attributes["variables"][$1] = value.to_s
    elsif(attributes["variable"] =~ /(.*) \/= ?(.*)/ || attributes["variable"] =~ /(.*)\/= ?(.*)/)
      value = attributes["variables"][$1].to_i / $2.to_i
      attributes["variables"][$1] = value.to_s
    elsif(attributes["variable"] =~ /(.*) = ?(.*)/ || attributes["variable"] =~ /(.*)= ?(.*)/)
      attributes["variables"][$1] = $2
    end
    attributes["variable_capture"] = false
    attributes["variable"] = String.new
  end

  def emit_variable(new_text, attributes)
    if(attributes["variable"][0] == "#")	# We are manipulating attributes["num"]
      if(attributes["variable"][1..-1] =~ /(.*) \-= ?(.*)/ ||
          attributes["variable"][1..-1] =~ /(.*)\-= ?(.*)/)
        attributes["num"] = pipetext(escape_fix(attributes["variables"][$1]), attributes["box_mode"],
            attributes["ampersand_mode"]).to_i - $2.to_i
      elsif(attributes["variable"][1..-1] =~ /(.*) \+= ?(.*)/ ||
          attributes["variable"][1..-1] =~ /(.*)\+= ?(.*)/)
        attributes["num"] = pipetext(escape_fix(attributes["variables"][$1]), attributes["box_mode"],
            attributes["ampersand_mode"]).to_i + $2.to_i
      elsif(attributes["variable"][1..-1] =~ /(.*) \*= ?(.*)/ ||
          attributes["variable"][1..-1] =~ /(.*)\*= ?(.*)/)
        attributes["num"] = pipetext(escape_fix(attributes["variables"][$1]), attributes["box_mode"],
            attributes["ampersand_mode"]).to_i * $2.to_i
      elsif(attributes["variable"][1..-1] =~ /(.*) \/= ?(.*)/ ||
          attributes["variable"][1..-1] =~ /(.*)\/= ?(.*)/)
        attributes["num"] = pipetext(escape_fix(attributes["variables"][$1]), attributes["box_mode"],
            attributes["ampersand_mode"]).to_i / $2.to_i
      else
        attributes["num"] = pipetext(escape_fix(attributes["variables"][attributes["variable"][1..-1]]),
            attributes["box_mode"], attributes["ampersand_mode"]).to_i
      end
      attributes["pipe"] = true
      attributes["found"] = false
    elsif(attributes["variables"][attributes["variable"]])
      new_text << pipetext(escape_fix(attributes["variables"][attributes["variable"]]),
          attributes["box_mode"], attributes["ampersand_mode"])
    else
      new_text << "|(" + attributes["variable"] + ")"
    end
    attributes["variable_capture"] = false
    attributes["variable"] = String.new
  end

  def emit_center(new_text, attributes)
    text = pipetext(attributes["center"], attributes["box_mode"], attributes["ampersand_mode"])
    length = printable_length(text)
    spaces = attributes["end"] - attributes["position"] - length
    if(length % 2)
      spaces += 1
    end
    if(spaces > 0)
      spaces /= 2
      spaces.times do
        new_text << " "
      end
    end
    new_text << text
    attributes["center_capture"] = false
    attributes["center"] = String.new
  end

  def emit_right(new_text, attributes)
    text = pipetext(attributes["right"], attributes["box_mode"], attributes["ampersand_mode"])
    length = printable_length(text)
    spaces = attributes["end"] - attributes["position"] - length
    if(spaces > 0)
      spaces.times do
        new_text << " "
      end
    end
    new_text << text
    attributes["right_capture"] = false
    attributes["right"] = String.new
  end

  def set_box_symbols(box_symbol, border_mode)
    if(border_mode == 1)
      box_symbol[:horizontal]   = "─"
      box_symbol[:vertical]     = "│"
      box_symbol[:top_left]     = "╭"
      box_symbol[:top_right]    = "╮"
      box_symbol[:bottom_left]  = "╰"
      box_symbol[:bottom_right] = "╯"
      box_symbol[:t_top]        = "┬"
      box_symbol[:t_bottom]     = "┴"
      box_symbol[:t_left]       = "├"
      box_symbol[:t_right]      = "┤"
      box_symbol[:cross]        = "┼"
    elsif(border_mode == 2)
      box_symbol[:horizontal]   = "═"
      box_symbol[:vertical]     = "║"
      box_symbol[:top_left]     = "╔"
      box_symbol[:top_right]    = "╗"
      box_symbol[:bottom_left]  = "╚"
      box_symbol[:bottom_right] = "╝"
      box_symbol[:t_top]        = "╦"
      box_symbol[:t_bottom]     = "╩"
      box_symbol[:t_left]       = "╠"
      box_symbol[:t_right]      = "╣"
      box_symbol[:cross]        = "╬"
    elsif(border_mode == 3)
      box_symbol[:horizontal]   = "─"
      box_symbol[:vertical]     = "│"
      box_symbol[:top_left]     = "┌"
      box_symbol[:top_right]    = "┐"
      box_symbol[:bottom_left]  = "└"
      box_symbol[:bottom_right] = "┘"
      box_symbol[:t_top]        = "┬"
      box_symbol[:t_bottom]     = "┴"
      box_symbol[:t_left]       = "├"
      box_symbol[:t_right]      = "┤"
      box_symbol[:cross]        = "┼"
    elsif(border_mode == 4)
      box_symbol[:horizontal]   = "━"
      box_symbol[:vertical]     = "┃"
      box_symbol[:top_left]     = "┏"
      box_symbol[:top_right]    = "┓"
      box_symbol[:bottom_left]  = "┗"
      box_symbol[:bottom_right] = "┛"
      box_symbol[:t_top]        = "┳"
      box_symbol[:t_bottom]     = "┻"
      box_symbol[:t_left]       = "┣"
      box_symbol[:t_right]      = "┫"
      box_symbol[:cross]        = "╋"
    elsif(border_mode == 5)
      box_symbol[:horizontal]   = "─"
      box_symbol[:vertical]     = "┃"
      box_symbol[:top_left]     = "┍"
      box_symbol[:top_right]    = "┑"
      box_symbol[:bottom_left]  = "└"
      box_symbol[:bottom_right] = "┘"
      box_symbol[:t_top]        = "┯"
      box_symbol[:t_bottom]     = "┷"
      box_symbol[:t_left]       = "┝"
      box_symbol[:t_right]      = "┥"
      box_symbol[:cross]        = "┿"
    elsif(border_mode == 6)
      box_symbol[:horizontal]   = "━"
      box_symbol[:vertical]     = "│"
      box_symbol[:top_left]     = "┎"
      box_symbol[:top_right]    = "┒"
      box_symbol[:bottom_left]  = "┖"
      box_symbol[:bottom_right] = "┚"
      box_symbol[:t_top]        = "┰"
      box_symbol[:t_bottom]     = "┸"
      box_symbol[:t_left]       = "┠"
      box_symbol[:t_right]      = "┨"
      box_symbol[:cross]        = "╂"
    elsif(border_mode == 7)
      box_symbol[:horizontal]   = "═"
      box_symbol[:vertical]     = "│"
      box_symbol[:top_left]     = "╒"
      box_symbol[:top_right]    = "╕"
      box_symbol[:bottom_left]  = "╘"
      box_symbol[:bottom_right] = "╛"
      box_symbol[:t_top]        = "╤"
      box_symbol[:t_bottom]     = "╧"
      box_symbol[:t_left]       = "╞"
      box_symbol[:t_right]      = "╡"
      box_symbol[:cross]        = "╪"
    elsif(border_mode == 8)
      box_symbol[:horizontal]   = "─"
      box_symbol[:vertical]     = "║"
      box_symbol[:top_left]     = "╓"
      box_symbol[:top_right]    = "╖"
      box_symbol[:bottom_left]  = "╙"
      box_symbol[:bottom_right] = "╜"
      box_symbol[:t_top]        = "╥"
      box_symbol[:t_bottom]     = "╨"
      box_symbol[:t_left]       = "╟"
      box_symbol[:t_right]      = "╢"
      box_symbol[:cross]        = "╫"
    elsif(border_mode == 9)
      box_symbol[:horizontal]   = "┄"
      box_symbol[:vertical]     = "┆"
      box_symbol[:top_left]     = "○"
      box_symbol[:top_right]    = "○"
      box_symbol[:bottom_left]  = "○"
      box_symbol[:bottom_right] = "○"
      box_symbol[:t_top]        = "⊹"
      box_symbol[:t_bottom]     = "⊹"
      box_symbol[:t_left]       = "⊹"
      box_symbol[:t_right]      = "⊹"
      box_symbol[:cross]        = "⊹"
    elsif(border_mode == 10)
      box_symbol[:horizontal]   = "✨"
      box_symbol[:vertical]     = "✨"
      box_symbol[:top_left]     = "🌸"
      box_symbol[:top_right]    = "🌸"
      box_symbol[:bottom_left]  = "🌸"
      box_symbol[:bottom_right] = "🌸"
      box_symbol[:t_top]        = "⭐"
      box_symbol[:t_bottom]     = "⭐"
      box_symbol[:t_left]       = "⭐"
      box_symbol[:t_right]      = "⭐"
      box_symbol[:cross]        = "🌟"
    elsif(border_mode == 11)
      box_symbol[:horizontal]   = "░"
      box_symbol[:vertical]     = "▒"
      box_symbol[:top_left]     = "▓"
      box_symbol[:top_right]    = "▓"
      box_symbol[:bottom_left]  = "▓"
      box_symbol[:bottom_right] = "▓"
      box_symbol[:t_top]        = "▒"
      box_symbol[:t_bottom]     = "▒"
      box_symbol[:t_left]       = "▒"
      box_symbol[:t_right]      = "▒"
      box_symbol[:cross]        = "▓"
    elsif(border_mode == 12)
      box_symbol[:horizontal]   = "⚜️"
      box_symbol[:vertical]     = "⚜️"
      box_symbol[:top_left]     = "💎"
      box_symbol[:top_right]    = "💎"
      box_symbol[:bottom_left]  = "💎"
      box_symbol[:bottom_right] = "💎"
      box_symbol[:t_top]        = "👑"
      box_symbol[:t_bottom]     = "👑"
      box_symbol[:t_left]       = "👑"
      box_symbol[:t_right]      = "👑"
      box_symbol[:cross]        = "⚜️"
    elsif(border_mode == 13)
      box_symbol[:horizontal]   = "🌿"
      box_symbol[:vertical]     = "🌿"
      box_symbol[:top_left]     = "🍃"
      box_symbol[:top_right]    = "🍃"
      box_symbol[:bottom_left]  = "🍂"
      box_symbol[:bottom_right] = "🍂"
      box_symbol[:t_top]        = "🌻"
      box_symbol[:t_bottom]     = "🌻"
      box_symbol[:t_left]       = "🌻"
      box_symbol[:t_right]      = "🌻"
      box_symbol[:cross]        = "🌳"
    elsif(border_mode == 14)
      box_symbol[:horizontal]   = "⚠️"
      box_symbol[:vertical]     = "⚠️"
      box_symbol[:top_left]     = "🚨"
      box_symbol[:top_right]    = "🚨"
      box_symbol[:bottom_left]  = "🚨"
      box_symbol[:bottom_right] = "🚨"
      box_symbol[:t_top]        = "⛔"
      box_symbol[:t_bottom]     = "⛔"
      box_symbol[:t_left]       = "⛔"
      box_symbol[:t_right]      = "⛔"
      box_symbol[:cross]        = "🧨"
    elsif(border_mode == 15)
      box_symbol[:horizontal]   = "✨"
      box_symbol[:vertical]     = "✨"
      box_symbol[:top_left]     = "☄️"
      box_symbol[:top_right]    = "☄️"
      box_symbol[:bottom_left]  = "☄️"
      box_symbol[:bottom_right] = "☄️"
      box_symbol[:t_top]        = "🌙"
      box_symbol[:t_bottom]     = "🌙"
      box_symbol[:t_left]       = "🌙"
      box_symbol[:t_right]      = "🌙"
      box_symbol[:cross]        = "☀️"
    elsif(border_mode == 16)
      box_symbol[:horizontal]   = "†"
      box_symbol[:vertical]     = "‡"
      box_symbol[:top_left]     = "⛧"
      box_symbol[:top_right]    = "⛧"
      box_symbol[:bottom_left]  = "⛧"
      box_symbol[:bottom_right] = "⛧"
      box_symbol[:t_top]        = "♱"
      box_symbol[:t_bottom]     = "♱"
      box_symbol[:t_left]       = "♱"
      box_symbol[:t_right]      = "♱"
      box_symbol[:cross]        = "☨"
    elsif(border_mode == 17)
      box_symbol[:horizontal]   = "🔥"
      box_symbol[:vertical]     = "🔥"
      box_symbol[:top_left]     = "💥"
      box_symbol[:top_right]    = "💥"
      box_symbol[:bottom_left]  = "💥"
      box_symbol[:bottom_right] = "💥"
      box_symbol[:t_top]        = "☀️"
      box_symbol[:t_bottom]     = "☀️"
      box_symbol[:t_left]       = "☀️"
      box_symbol[:t_right]      = "☀️"
      box_symbol[:cross]        = "🌋"
    elsif(border_mode == 18)
      box_symbol[:horizontal]   = "〓"
      box_symbol[:vertical]     = "〓"
      box_symbol[:top_left]     = "⬜"
      box_symbol[:top_right]    = "⬜"
      box_symbol[:bottom_left]  = "⬜"
      box_symbol[:bottom_right] = "⬜"
      box_symbol[:t_top]        = "◽"
      box_symbol[:t_bottom]     = "◽"
      box_symbol[:t_left]       = "◽"
      box_symbol[:t_right]      = "◽"
      box_symbol[:cross]        = "◻️"
    elsif(border_mode == 19)
      box_symbol[:horizontal]   = "〰️"
      box_symbol[:vertical]     = "⌇"
      box_symbol[:top_left]     = "📜"
      box_symbol[:top_right]    = "📜"
      box_symbol[:bottom_left]  = "📜"
      box_symbol[:bottom_right] = "📜"
      box_symbol[:t_top]        = "🏺"
      box_symbol[:t_bottom]     = "🏺"
      box_symbol[:t_left]       = "🏺"
      box_symbol[:t_right]      = "🏺"
      box_symbol[:cross]        = "🗝️"
    elsif(border_mode == 20)
      box_symbol[:horizontal]   = "≈"
      box_symbol[:vertical]     = "≋"
      box_symbol[:top_left]     = "🐚"
      box_symbol[:top_right]    = "🐚"
      box_symbol[:bottom_left]  = "🐚"
      box_symbol[:bottom_right] = "🐚"
      box_symbol[:t_top]        = "🌊"
      box_symbol[:t_bottom]     = "🌊"
      box_symbol[:t_left]       = "🌊"
      box_symbol[:t_right]      = "🌊"
      box_symbol[:cross]        = "⚓"
    elsif(border_mode == 21)
      box_symbol[:horizontal]   = "💕"
      box_symbol[:vertical]     = "💕"
      box_symbol[:top_left]     = "💖"
      box_symbol[:top_right]    = "💖"
      box_symbol[:bottom_left]  = "💖"
      box_symbol[:bottom_right] = "💖"
      box_symbol[:t_top]        = "💗"
      box_symbol[:t_bottom]     = "💗"
      box_symbol[:t_left]       = "💗"
      box_symbol[:t_right]      = "💗"
      box_symbol[:cross]        = "❤️"
    else
      box_symbol[:horizontal]   = "-"
      box_symbol[:vertical]     = "|"
      box_symbol[:top_left]     = "["
      box_symbol[:top_right]    = "]"
      box_symbol[:bottom_left]  = "["
      box_symbol[:bottom_right] = "]"
      box_symbol[:t_top]        = "+"
      box_symbol[:t_bottom]     = "+"
      box_symbol[:t_left]       = "+"
      box_symbol[:t_right]      = "+"
      box_symbol[:cross]        = "+"
    end
  end

  def wide_border_mode(border_mode)
    scratch = Hash.new
    set_box_symbols(scratch, border_mode)
    if(double_wide_character(scratch[:horizontal]))
      return true
    end
    return false
  end

  def max_line_length(line, max)
    if(line =~ /^(.*)\|\\n(.*)$/m || line =~ /^([^\n]*)\n(.*)$/m)
      if($1 != nil)
        length = printable_length($1)
        if(length > max)
          max = length
        end
      end
      return max_line_length($2, max)
    elsif(line != nil)
      length = printable_length(line)
      if(length > max)
        max = length
      end
    end
    return max
  end

  def max_line_count(line, count)
    if(line =~ /^(.*)\|\\n(.*)$/)
      if($1 =~ /\n/)
        count += $1.count("\n")
      else
        count += 1
      end
      return max_line_count($2, count)
    elsif(line != nil)
      if(line =~ /\n/)
        count += line.count("\n")
      else
        count += 1
      end
    else
      count += 1
    end
    return count
  end

  def update_box_attributes(attributes)
    min_height = 0
    min_width = 0
    1.upto(attributes["boxes"]) do |box_num|
      box = attributes["box_attributes"][box_num]
      if(box["attributes"] =~ /grow/i)
        box["grow"] = true
      else
        box["grow"] = false
      end
      if(box["attributes"] =~ /(?<!inside|outside )border background color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /(?<!inside|outside )border bg color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /(?<!inside|outside )border bg *[=:]? ([^ ,;\]]*)/i)
        box["border_background_color"] = pipetext($1, true, true)
      else
        box["border_background_color"] = pipetext("&n", true, true)
      end
      if(box["attributes"] =~ /inside border background color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /inside border bg color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /inside border bg *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /padding bg color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /padding color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /padding bg *[=:]? ([^ ,;\]]*)/i)
        box["inside_border_background_color"] = pipetext($1, true, true)
      else
        box["inside_border_background_color"] = box["border_background_color"]
      end
      if(box["attributes"] =~ /outside (?:border )background color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /outside (?:border )bg color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /outside (?:border )bg *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /margin bg color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /margin color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /margin bg *[=:]? ([^ ,;\]]*)/i)
        box["outside_border_background_color"] = pipetext($1, true, true)
      else
        box["outside_border_background_color"] = box["border_background_color"]
      end
      if(box["attributes"] =~ /(?<!border )background color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /(?<!border )bg color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /(?<!border )bg *[=:]? ([^ ,;\]]*)/i)
        box["bg_pipe_color"] = $1
      else
        box["bg_pipe_color"] = "&n"
      end
      box["background_color"] = pipetext(box["bg_pipe_color"], true, true)
      if(box["attributes"] =~ /border foreground color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /border fg color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /border fg *[=:]? ([^ ,;\]]*)/i)
        box["border_foreground_color"] = pipetext($1, true, true)
      else
        box["border_foreground_color"] = pipetext("|n", true, true)
      end
      if(box["attributes"] =~ /(?<!border )foreground color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /(?<!border )fg color *[=:]? ([^ ,;\]]*)/i ||
          box["attributes"] =~ /(?<!border )fg *[=:]? ([^ ,;\]]*)/i)
        box["fg_pipe_color"] = $1
      else
        box["fg_pipe_color"] = "|n"
      end
      box["foreground_color"] = pipetext(box["fg_pipe_color"], true, true)
      if(box["attributes"] =~ /inside (?:border )*[=:]? *([0-9]+)/i ||
          box["attributes"] =~ /padding *[=:]? *([0-9]+)/i)
        box["inside_border"] = $1.to_i
      else
        box["inside_border"] = 0
      end
      if(box["attributes"] =~ /outside (?:border )*[=:]? *([0-9]+)/i ||
          box["attributes"] =~ /margin *[=:]? *([0-9]+)/i)
        box["outside_border"] = $1.to_i
      else
        box["outside_border"] = 0
      end
      if(box["attributes"] =~ /(?<!side )border mode *[=:]? *([\-0-9]+)/i ||
          box["attributes"] =~ /(?<!side )border *[=:]? *([\-0-9]+)/i ||
          box["attributes"] =~ /mode *[=:]? *([\-0-9]+)/i)
        box["border_mode"] = $1.to_i
      elsif(box["attributes"] =~ /mode *[=:]? *off/i)
        box["border_mode"] = -1
      else
        box["border_mode"] = 1
      end
      if(box["attributes"] =~ /title *[=:]? \"(.*)\"/i)
        box["title"] = $1
      elsif(box["attributes"] =~ /title *[=:]? '(.*)'/i)
        box["title"] = $1
      else
        box["title"] = String.new
      end
      if(box["attributes"] =~ /height *[=:]? *max/i)
        box["height"], _ = IO.console.winsize
      elsif(box["attributes"] =~ /height *[=:]? *([0-9]+)/i)
        box["height"] = $1.to_i
        if(box["grow"] == true && box["parent"] == 0)
          box["height"], _ = IO.console.winsize
        end
      else
        box["height"] = 0
        if(box["capture"] != "")
          box["capture"].lines.each do |line|
            box["height"] = max_line_count(pipetext(line, attributes["box_mode"],
                attributes["ampersand_mode"]), box["height"])
          end
        end
        if(box["title"] != "")
          box["height"] = max_line_count(pipetext(box["title"], attributes["box_mode"],
              attributes["ampersand_mode"]), box["height"])
          box["height"] += 1
        end
        if(box["border_mode"] > 0)
          box["height"] += 2
        end
        if(box["inside_border"] > 0)
          box["height"] += (box["inside_border"] * 2)
        end
        if(box["outside_border"] > 0)
          box["height"] += (box["outside_border"] * 2)
        end
      end
      if(box["height"] < 2)
        box["height"] = 2
      end
      if(box["attributes"] =~ /width *[=:]? *max/i)
        _, box["width"] = IO.console.winsize
      elsif(box["attributes"] =~ /width *[=:]? *([0-9]+)/i)
        box["width"] = $1.to_i
        if(box["grow"] == true && box["parent"] == 0)
          _, box["width"] = IO.console.winsize
        end
      else
        box["width"] = 0
        if(box["capture"] != "")
          width = 0
          box_num = attributes["box_capture"]
          attributes["box_capture"] = 0
          box["capture"].lines.each do |line|
            box["width"] = max_line_length(pipe(line, attributes), box["width"])
          end
          attributes["box_capture"] = box_num
        end
        if(box["title"] != "")
          box_num = attributes["box_capture"]
          attributes["box_capture"] = 0
          box["width"] = max_line_length(pipe(box["title"], attributes), box["width"])
          attributes["box_capture"] = box_num
        end
        if(box["border_mode"] > 0)
          box["width"] += 2
          if(wide_border_mode(box["border_mode"]) == true)
            box["width"] += 2
          end
        end
        if(box["inside_border"] > 0)
          box["width"] += (box["inside_border"] * 2)
        end
        if(box["outside_border"] > 0)
          box["width"] += (box["outside_border"] * 2)
        end
      end
      if(box["width"] < 4 && wide_border_mode(box["border_mode"]) == true)
        box["width"] = 4
      elsif(box["width"] < 2)
        box["width"] = 2
      end
      if(box["attributes"] =~ /layout *[=:]? *horizontal/i)
        box["layout"] = "horizontal"
      else
        box["layout"] = "vertical"
      end
      if(box["attributes"] =~ /clip/i)
        box["clip_children"] = true
      else
        box["clip_children"] = false
      end
    end
  end

  def box_set(x, y, symbol, background=nil, foreground=nil)
    @drawing[[x, y]] = { "symbol" => symbol, "bg" => background, "fg" => foreground }
    @bounds["min_x"] = [@bounds["min_x"], x].min
    @bounds["max_x"] = [@bounds["max_x"], x].max
    @bounds["min_y"] = [@bounds["min_y"], y].min
    @bounds["max_y"] = [@bounds["max_y"], y].max
  end

  def process_box_line(text_x, text_y, bg_color, fg_color, line)
    escape = false
    bracket = false
    join = false
    collect = String.new
    line.each_char do |character|
      if(character == "\e")
        escape = true
        collect << "\e"
      elsif(escape == true && bracket == false && character == "[")
        bracket = true
        collect << "["
      elsif(escape == true)
        collect << character
        if(character >= "@" && character <= "~")
          escape = false
          bracket = false
        end
      elsif(character[0].ord == 8205)
        join = true
        @drawing[[text_x - 1, text_y]]["symbol"] << character
      elsif(character[0].ord == 65039)
        @drawing[[text_x - 1, text_y]]["symbol"] << character
        if(@drawing[[text_x, text_y]]["symbol"] == " ")
          @drawing[[text_x, text_y]]["symbol"] = ""
        end
      elsif(character[0].ord >= 917602 && character[0].ord <= 917631)
        @drawing[[text_x - 1, text_y]]["symbol"] << character
      elsif(character[0].ord >= 127462 && character[0].ord <= 127487 &&
          @drawing[[text_x - 1, text_y]]["symbol"][-1].ord >= 127462 &&
          @drawing[[text_x - 1, text_y]]["symbol"][-1].ord <= 127487 &&
          (@drawing[[text_x - 1, text_y]]["symbol"][-2] == nil ||
          @drawing[[text_x - 1, text_y]]["symbol"][-2].ord < 127462 ||
          @drawing[[text_x - 1, text_y]]["symbol"][-2].ord > 127487))
        @drawing[[text_x - 1, text_y]]["symbol"] << character
      elsif(join == true)
        @drawing[[text_x - 1, text_y]]["symbol"] << character
        join = false
      else
        box_set(text_x, text_y, collect + character, bg_color, fg_color)
        collect = String.new
        text_x += 1
      end
    end
  end

  def set_box_lines(text_x, text_y, bg_color, fg_color, line, max_height)
    if(text_y > max_height)
      return max_height
    end
    if(line == nil)
      return text_y
    elsif(line =~ /^(.*)|\\n(.*)$/)
      line1 = $1
      line2 = $2
      if(line1 != nil)
        process_box_line(text_x, text_y, bg_color, fg_color, line1)
        text_y += 1
      end
      if(line2 == nil)
        return text_y
      end
      return set_box_lines(text_x, text_y, bg_color, fg_color, line2, max_height)
    else
      if(line != nil)
        process_box_line(text_x, text_y, bg_color, fg_color, line)
        text_y += 1
      end
    end
    return text_y
  end

  def draw_box_outside_border(attributes, box, x, y, width, height)
    border_size = box["outside_border"]
    if(border_size > 0)
      horizontal_range = (x...x + width)
      vertical_range = (y...y + height)
      vertical_range.each do |row|
        horizontal_range.each do |column|
          if(column >= attributes["box_attributes"][1]["width"] - 1 ||
              (row >= attributes["box_attributes"][1]["height"] - 1 && column == x + width - 1))
            box_set(column + 1, row, " ", "\e[49m", "\e[39m")
          end
          location = @drawing[[x - 1, row]]
          if(location != nil && double_wide_character(location["symbol"]))
            location["symbol"] = " "
          end
          if(row <= y + border_size || row >= y + height - border_size - 1 ||
              column <= x + border_size || column >= x + width - border_size - 1)
            box_set(column, row, " ", box["outside_border_background_color"], box["foreground_color"])
          end
        end
      end
    end
  end

  def draw_box_frame(box, x, y, width, height)
    title_height = 0
    box_symbol = Hash.new
    wide_border = false

    y_offset = x_offset = 0
    if(box["border_mode"] > 0)
      set_box_symbols(box_symbol, box["border_mode"])
      if(double_wide_character(box_symbol[:horizontal]))
        wide_border = true
      end
    end
    x_offset += box["outside_border"]
    y_offset += box["outside_border"]
    if(box["title"] != "")
      text_y = y + y_offset + 1
      text_x = x + x_offset + 1
      if(wide_border == true)
        text_x += 1
      end
      new_attributes = pipetext_init
      new_attributes["remap"] = { "|n" => box["fg_pipe_color"], "&n" => box["bg_pipe_color"] }
      new_attributes["ampersand_mode"] = true
      new_attributes["end"] = width
      if(box["border_mode"] > 0)
        if(wide_border == true)
          new_attributes["end"] -= 4
        else
          new_attributes["end"] -= 2
        end
      end
      new_attributes["end"] -= (2 * x_offset)
      if(new_attributes["end"] > 0)
        new_attributes["position"] = 0
        box["title"] = pipe(box["title"], new_attributes)
        if(text_y < y + height && box["title"] != "")
          box["title"].lines.each do |line|
            if(text_y < y + height)
              text_y = set_box_lines(text_x, text_y, box["background_color"], box["foreground_color"], line, y + height)
              title_height = text_y - (y + y_offset + 1)
            end
          end
        end
      end
    end

    toggle = false
    horizontal_range = (x + x_offset + 1...x + width - x_offset - 1)
    horizontal_range.each do |column|
      if(wide_border == false || (wide_border == true && toggle == true && column < horizontal_range.last))
        if(wide_border == false)
          box_set(column, y + y_offset, box_symbol[:horizontal], box["border_background_color"], box["border_foreground_color"])
          box_set(column, y + height - y_offset - 1, box_symbol[:horizontal], box["border_background_color"], box["border_foreground_color"])
          if(box["title"] != "")
            box_set(column, title_height + y_offset + 1, box_symbol[:horizontal], box["border_background_color"], box["border_foreground_color"])
          end
        else
          box_set(column, y + y_offset, box_symbol[:horizontal], box["border_background_color"], box["border_foreground_color"])
          box_set(column, y + height - y_offset - 1, box_symbol[:horizontal], box["border_background_color"], box["border_foreground_color"])
          if(box["title"] != "")
            box_set(column, title_height + y_offset + 1, box_symbol[:horizontal], box["border_background_color"], box["border_foreground_color"])
          end
        end
        toggle = false
      else
        toggle = true            
      end
    end

    toggle = true
    vertical_range = (y + y_offset + 1...y + height - y_offset - 1)
    vertical_range.each do |row|
      if(wide_border == false || (wide_border == true && toggle == true && row < vertical_range.last))
        location = @drawing[[x + x_offset - 1, row]]
        if(location != nil && double_wide_character(location["symbol"]))
          location["symbol"] = " "
        end
        if(wide_border == false)
          box_set(x + x_offset, row, box_symbol[:vertical], box["border_background_color"], box["border_foreground_color"])
          box_set(x + width - x_offset - 1, row, box_symbol[:vertical], box["border_background_color"], box["border_foreground_color"])
        else
          box_set(x + x_offset, row, box_symbol[:vertical], box["border_background_color"], box["border_foreground_color"])
          box_set(x + width - x_offset - 2, row, box_symbol[:vertical], box["border_background_color"], box["border_foreground_color"])
        end
      else
        toggle = true
      end
    end
    location = @drawing[[x + x_offset - 1, y + y_offset]]
    if(location != nil && double_wide_character(location["symbol"]))
      location["symbol"] = " "
    end
    location = @drawing[[x + x_offset - 1, y + height - y_offset]]
    if(location != nil && double_wide_character(location["symbol"]))
      location["symbol"] = " "
    end
    if(wide_border == false)
      box_set(x + x_offset, y + y_offset, box_symbol[:top_left], box["border_background_color"], box["border_foreground_color"])
      box_set(x + width - x_offset - 1, y + y_offset, box_symbol[:top_right], box["border_background_color"], box["border_foreground_color"])
      box_set(x + x_offset, y + height - y_offset - 1, box_symbol[:bottom_left], box["border_background_color"], box["border_foreground_color"])
      box_set(x + width - x_offset - 1, y + height - y_offset - 1, box_symbol[:bottom_right], box["border_background_color"], box["border_foreground_color"])
      if(box["title"] != "")
        box_set(x + x_offset, y + y_offset + title_height + 1, box_symbol[:t_left], box["border_background_color"], box["border_foreground_color"])
        box_set(x + width - x_offset - 1, y + y_offset + title_height + 1, box_symbol[:t_right], box["border_background_color"], box["border_foreground_color"])
      end
    else
      box_set(x + x_offset, y + y_offset, box_symbol[:top_left], box["border_background_color"], box["border_foreground_color"])
      box_set(x + width - x_offset - 2, y + y_offset, box_symbol[:top_right], box["border_background_color"], box["border_foreground_color"])
      box_set(x + x_offset, y + height - y_offset - 1, box_symbol[:bottom_left], box["border_background_color"], box["border_foreground_color"])
      box_set(x + width - x_offset - 2, y + height - y_offset - 1, box_symbol[:bottom_right], box["border_background_color"], box["border_foreground_color"])
    end
    if(wide_border == true)
      x_offset += 2
    else
      x_offset += 1
    end
    y_offset += title_height
    y += title_height + 1
    return y, wide_border, x_offset, y_offset
  end

  def draw_box_inside_border(box, x, y, width, height, x_offset, y_offset, wide_frame_border)
    border_size = box["inside_border"]
    if(border_size > 0)
#      if(wide_frame_border == true)
#        horizontal_range = (x + x_offset + 1...x + width - x_offset - 1)
#      else
#        horizontal_range = (x + x_offset - 1...x + width - x_offset + 1)
#      end
      horizontal_range = (x + x_offset...x + width - x_offset)
      vertical_range = (y + y_offset...y + height - y_offset - 2)
      vertical_range.each do |row|
        horizontal_range.each do |column|
          location = @drawing[[x - 1, row]]
          if(location != nil && double_wide_character(location["symbol"]))
            location["symbol"] = " "
          end
#          if(wide_frame_border == true)
#            if(row < y + y_offset + border_size || row >= y + height - y_offset - border_size - 2 ||
#                column <= x + x_offset + border_size || column >= x + width - x_offset - border_size - 1)
#              box_set(column, row, " ", box["inside_border_background_color"], box["foreground_color"])
#            end
#          else
#            if(row < y + y_offset + border_size || row >= y + height - y_offset - border_size - 2 ||
#                column < x + x_offset + border_size - 1 || column > x + width - x_offset - border_size)
#              box_set(column, row, " ", box["inside_border_background_color"], box["foreground_color"])
#            end
#          end
          if(row < y + y_offset + border_size || row >= y + height - y_offset - border_size - 2 ||
              column < x + x_offset + border_size || column > x + width - x_offset - border_size - 1)
            box_set(column, row, " ", box["inside_border_background_color"], box["foreground_color"])
          end
        end
      end
    end
  end

  def draw_box_background(box, x, y, height, width)
    horizontal_range = (x + 1...x + width - 1)
    vertical_range = (y + 1...y + height - 1)
    vertical_range.each do |row|
      horizontal_range.each do |column|
        box_set(column, row, " ", box["background_color"], box["foreground_color"])
      end
    end
  end

  def draw_box_text(box, x, y, width, height, x_offset, y_offset)
    text_x = x + x_offset
    text_y = y + y_offset
    new_attributes = pipetext_init
    new_attributes["remap"] = { "|n" => box["fg_pipe_color"], "&n" => box["bg_pipe_color"] }
    new_attributes["ampersand_mode"] = true
    new_attributes["end"] = width
    new_attributes["position"] = 0
    box["capture"] = pipe(box["capture"], new_attributes)
    if(text_y < y + height && box["capture"] != "")
      box["capture"].lines.each do |line|
        if(text_y < y + height)
          text_y = set_box_lines(text_x, text_y, box["background_color"], box["foreground_color"], line, y + height)
        end
      end
    end
    return text_y - y_offset
  end

  def draw_box_children(attributes, box_index, x, y, width, height, x_offset, y_offset)
    box = attributes["box_attributes"][box_index]
    inside_x = x + x_offset
    inside_y = y + y_offset
    inside_width = width - (x_offset * 2)
    inside_height = height - (y_offset * 2)
    current_x = inside_x
    current_y = inside_y
    attributes["box_attributes"].each do |index, inside_box|
      if(inside_box["parent"] == box_index)
        inside_width = inside_box["width"]
        inside_height = inside_box["height"]
        if(box["layout"] == "horizontal")
          available_width = width - x_offset - current_x
          available_height = height - current_y - 1
          if(inside_box["grow"] == true)
            inside_width = available_width
            inside_height = available_height
          end
          if(box["clip_children"] == true)
            inside_width = [inside_width, available_width].min
            inside_height = [inside_height, available_height].min
          end
          if(inside_width > 2 && inside_height > 2)
            box_draw(attributes, index, current_x, current_y, inside_width, inside_height)
            current_x += inside_width
          end
        else
          available_width = (x + width - x_offset) - current_x
          available_height = (y + height - (2 * y_offset)) - current_y - 1
          if(inside_box["grow"] == true)
            inside_width = available_width
            inside_height = available_height
          end
          if(box["clip_children"] == true)
            inside_width = [inside_width, available_width].min
            inside_height = [inside_height, available_height].min
          end
          if(inside_width > 2 && inside_height > 2)
            box_draw(attributes, index, current_x, current_y, inside_width, inside_height)
            current_y += inside_height
          end
        end
      end
    end
  end

  def box_draw(attributes, box_index, x, y, override_width=nil, override_height=nil)
    x_offset = 0
    y_offset = 0
    box = attributes["box_attributes"][box_index]
    if(override_width)
      width = override_width
    else
      width = box["width"]
    end
    if(override_height)
      height = override_height
    else
      height = box["height"]
    end
    if(box["outside_border"] > 0)
      draw_box_outside_border(attributes, box, x, y, width, height)
    end
    draw_box_background(box, x, y, height, width)
    if(box["border_mode"] >= 0)
      y, wide_frame_border, x_offset, y_offset = draw_box_frame(box, x, y, width, height)
    end
    draw_box_inside_border(box, x, y, width, height, x_offset, y_offset, wide_frame_border)
    x_offset += box["inside_border"]
    y_offset += box["inside_border"]
    text_width = width - (2 * box["outside_border"])
    text_height = height - (2 * box["outside_border"])
    if(box["border_mode"] >= 0)
      text_width -= 2
      text_height -= 2
      if(wide_frame_border == true)
        text_width -= 2
      end
    end
    text_width -= (2 * box["inside_border"])
    text_height -= (2 * box["inside_border"])
    y = draw_box_text(box, x, y, text_width, text_height, x_offset, y_offset)
    draw_box_children(attributes, box_index, x, y, width, height, x_offset, y_offset)
  end

  def box_render
    result = String.new
    rendered_box = Array.new
    y_render_range = (@bounds["min_y"]..@bounds["max_y"])
    y_render_range.each do |y|
      row = Array.new
      x_render_range = (@bounds["min_x"]..@bounds["max_x"])
      previous_bg = String.new
      previous_fg = String.new
      offset = 0
      wide = 0
      x_render_range.each do |x|
        location = @drawing[[x + offset, y]]
        if(!location)
          if(wide > 0)
            wide -= 1
          else
            row << " "
          end
        elsif(wide > 0 && location["symbol"] == " ")
          wide -= 1
        else
          if(double_wide_character(location["symbol"]))
            wide += 1
          end
          bg = String.new
          if(location["bg"])
            bg = location["bg"]
          end
          fg = String.new
          if(location["fg"])
            fg = location["fg"]
          end
          if(previous_bg == bg && previous_fg == fg)
            row << location["symbol"]
          elsif(previous_bg != bg && previous_fg == fg)
            row << bg + location["symbol"]
          elsif(previous_bg == bg && previous_fg != fg)
            row << fg + location["symbol"]
          else
            row << bg + fg + location["symbol"]
          end
          previous_fg = fg
          previous_bg = bg
        end
      end
      rendered_box << row.join
    end
    rendered_box.each do |line|
      result << line + "\e[49m\e[39m\n"
    end
    return result
  end

  def emit_box(new_text, attributes)
    @drawing = Hash.new
    @bounds = { "min_x" => Float::INFINITY, "max_x" => -Float::INFINITY,
                "min_y" => Float::INFINITY, "max_y" => -Float::INFINITY }
    update_box_attributes(attributes)
    box_draw(attributes, 1, 0, 0)
    new_text << box_render
    attributes["box_capture"] = 0
    attributes["boxes"] = 0
    attributes["box_attributes"] = Hash.new
  end

  def emit_emoji(new_text, attributes)
    emoji = String.new
    match_length = 0
    value_length = 0
    $substitute_emoji_names.each do |key, value|
      if(attributes["emoji"] == key)			# Use the most precise match first
        emoji = value
        break
      elsif(attributes["emoji"].length <= key.length)	# Otherwise use shortest match
        match = abbreviated_match(attributes["emoji"], key)
        if(match == 0 && key =~ /-/)
          match = abbreviated_match(attributes["emoji"], key.sub(/-/, " "))
        end
        if(match > 0 && (match <= match_length || match_length == 0) && 
            (value.length <= value_length || value_length == 0))
          emoji = value
          match_length = match
          value_length = value.length
        end
      end
    end
    if(emoji == String.new)		# No match, put copy input
      new_text << "|[" + attributes["emoji"] + "]"
    else
      emoji.split(/\|U/).each do |e|
        if(e != "")
          attributes["unicode"] = e.sub(/^\+?/, "")
          emit_unicode(new_text, attributes)
        end
      end
      attributes["emoji"] = String.new
    end
    attributes["emoji_capture"] = false
  end

  def process_pipe(character, new_text, attributes)
    if(attributes["pipe"] == true && attributes["num"] == 0)      # ||
      attributes["pipe"] = false
      new_text << character
    else
      attributes["pipe"] = true
    end
  end

  def process_repeat_pattern(character, new_text, attributes)
    if(attributes["repeat_pattern"] == true)  # ~ at end of |5~Repeat 5 times~
      attributes["num"].times do
        new_text << pipetext(attributes["pattern"], attributes["box_mode"], attributes["ampersand_mode"])
      end
      attributes["num"] = 0
      attributes["pipe"] = false
      attributes["escape"] = false
      attributes["repeat_pattern"] = false
      attributes["pattern"] = String.new
    else                                # ~ after number in |5~Repeat 5 times~
      attributes["repeat_pattern"] = true
    end
  end

  def escape_fix(text) # Done this way for old Ruby versions
    text = text.gsub(/\\a/, "\a").gsub(/\\b/, "\b").gsub(/\\e/, "\e").gsub(/\\f/, "\f")
    text = text.gsub(/\\n/, "\n").gsub(/\\r/, "\r").gsub(/\\t/, "\t").gsub(/\\v/, "\v")
    text = text.gsub(/\\~/, "~").gsub(/\\\(/, "(").gsub(/\\\)/, ")")
  end

  def process_escaped_character(character, new_text, attributes)
    if(attributes["num"] > 0)
      attributes["num"].times do
        new_text << escape_fix("\\#{character}")
      end
    else
      new_text << escape_fix("\\#{character}")
    end
    attributes["num"] = 0
    attributes["pipe"] = false
    attributes["escape"] = false
    attributes["pattern"] = String.new
    attributes["repeat_pattern"] = false
  end

  def capture_color(character, new_text, attributes)
    if(character =~ /[0-9,A-F,a-f]/)
      if(attributes["color_capture"] <= 2)
        attributes["r"] << character
      elsif(attributes["color_capture"] <= 4)
        attributes["g"] << character
      elsif(attributes["color_capture"] <= 6)
        attributes["b"] << character
      end
      if(attributes["color_capture"] == 6)
        emit_color(new_text, attributes)
      else
        attributes["color_capture"] += 1
      end
    end
  end

  def capture_character_pattern(character, attributes)
    if(character == "\\")
      attributes["escape"] = true
    else
      if(attributes["escape"] == true)
        attributes["pattern"] << "\\#{character}"
        attributes["escape"] = false
      else
        attributes["pattern"] << character
      end
    end
  end

  def capture_palette_color(character, new_text, attributes)
    if(character =~ /[0-9,A-F,a-f]/)
      if(attributes["palette_capture"] <= 2)
        attributes["p"] << character
      end
      if(attributes["palette_capture"] == 2)
        emit_palette_color(new_text, attributes)
      else
        attributes["palette_capture"] += 1
      end
    end
  end

  def capture_unicode(character, new_text, attributes)
    if(character =~ /[0-9,A-F,a-f]/)
      if(attributes["unicode_capture"] <= 6)
        attributes["unicode"] << character
      end
      if(attributes["unicode_capture"] == 6)
        emit_unicode(new_text, attributes)
      else
        attributes["unicode_capture"] += 1
      end
    end
  end

  def process_ampersand(character, new_text, attributes)
    if(attributes["ampersand"] == true)         # &&
      attributes["ampersand"] = false
      new_text << character
    else
      attributes["ampersand"] = true
    end
  end

  def test_shell_add(attributes, text)
    if(attributes["shell_prompt"] == true)
      return "\\[#{text}\\]"
    else
      return text
    end
  end

  def process_piped_character(character, new_text, attributes)
    attributes["found"] = true                  # Assume we will find the next character
    if(attributes["num"] == 0)                  # We are not in repeat character mode
      case character
      when "&"                                  # |&       - Toggle & on/off for Background Colors
        if(attributes["ampersand_mode"] == true)
          attributes["ampersand_mode"] = false
        else
          attributes["ampersand_mode"] = true
        end
        attributes["pipe"] = false
      when "!"                                  # |!       - Clear screen
        new_text << test_shell_add(attributes, "\e[H\e[J")
      when "+"                                  # |+       - Bold
        if(attributes["bold"] == false)
          new_text << test_shell_add(attributes, "\e[1m")
          attributes["bold"] = true
        else
          new_text << test_shell_add(attributes, "\e[22m")
          attributes["bold"] = false
        end
      when "."                                  # |.       - Faint / Dim
        if(attributes["faint"] == false)
          new_text << test_shell_add(attributes, "\e[2m")
          attributes["faint"] = true
        else
          new_text << test_shell_add(attributes, "\e[22m")
          attributes["faint"] = false
        end
      when "~"                                  # |~       - Italic
        if(attributes["italic"] == false)
          new_text << test_shell_add(attributes, "\e[3m")
          attributes["italic"] = true
        else
          new_text << test_shell_add(attributes, "\e[23m")
          attributes["italic"] = false
        end
      when "_"                                  # |_       - Underline
        if(attributes["underline"] == false)
          new_text << test_shell_add(attributes, "\e[4m")
          attributes["underline"] = true
        else
          new_text << test_shell_add(attributes, "\e[24m")
          attributes["underline"] = false
        end
      when "@"                                  # |@       - Blink
        if(attributes["blink"] == false)
          new_text << test_shell_add(attributes, "\e[5m")
          attributes["blink"] = true
        else
          new_text << test_shell_add(attributes, "\e[25m")
          attributes["blink"] = false
        end
      when "^"                                  # |^       - Move up 1 line
        new_text << "\e[A"
      when "v", "V"                             # |v       - Move down 1 line
        new_text << "\e[B"
      when ">"                                  # |>       - Move forward 1 character
        new_text << "\e[C"
      when "<"                                  # |<       - Move back 1 character
        new_text << "\e[D"
      when "h"                                  # |h       - Hide cursor
        new_text << test_shell_add(attributes, "\e[?25l")
      when "H"                                  # |H       - Unhide cursor
        new_text << test_shell_add(attributes, "\e[?25h")
      when "i", "I"                             # |i       - Inverse
        if(attributes["inverse"] == false)
          new_text << test_shell_add(attributes, "\e[7m")
          attributes["inverse"] = true
        else
          new_text << test_shell_add(attributes, "\e[27m")
          attributes["inverse"] = false
        end
      when "x", "X"                             # |x       - Crossed Out
        if(attributes["crossed_out"] == false)
          new_text << test_shell_add(attributes, "\e[9m")
          attributes["crossed_out"] = true
        else
          new_text << test_shell_add(attributes, "\e[29m")
          attributes["crossed_out"] = false
        end
      when "#"                                  # |#RRGGBB
        attributes["color_capture"] = 1
      when "P", "p"                             # |P or |p - 2 character hex format color (256 colors)
        attributes["palette_capture"] = 1
      when "U", "u"                             # |U or |u - Unicode 6 character hex format
        attributes["unicode_capture"] = 1
      when "k"                                  # |k - Foreground text black
        if(attributes["fg"] != "\e[30m")
          attributes["fg"] = "\e[30m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "K"                                  # |K - Foreground text bright black
        if(attributes["fg"] != "\e[90m")
          attributes["fg"] = "\e[90m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "r"                                  # |r       - Foreground text red
        if(attributes["fg"] != "\e[31m")
          attributes["fg"] = "\e[31m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "R"                                  # |R       - Foreground text bright red
        if(attributes["fg"] != "\e[91m")
          attributes["fg"] = "\e[91m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "g"                                  # |g       - Foreground text green
        if(attributes["fg"] != "\e[32m")
          attributes["fg"] = "\e[32m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "G"                                  # |G       - Foreground text bright green
        if(attributes["fg"] != "\e[92m")
          attributes["fg"] = "\e[92m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "y"                                  # |y       - Foreground text yellow (brown)
        if(attributes["fg"] != "\e[33m")
          attributes["fg"] = "\e[33m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "Y"                                  # |Y       - Foreground text bright yellow
        if(attributes["fg"] != "\e[93m")
          attributes["fg"] = "\e[93m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "b"                                  # |b       - Foreground text blue
        if(attributes["fg"] != "\e[34m")
          attributes["fg"] = "\e[34m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "B"                                  # |B       - Foreground text bright blue
        if(attributes["fg"] != "\e[94m")
          attributes["fg"] = "\e[94m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "m"                                  # |m       - Foreground text magenta
        if(attributes["fg"] != "\e[35m")
          attributes["fg"] = "\e[35m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "M"                                  # |M       - Foreground text bright magenta
        if(attributes["fg"] != "\e[95m")
          attributes["fg"] = "\e[95m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "c"                                  # |c       - Foreground text cyan
        if(attributes["fg"] != "\e[36m")
          attributes["fg"] = "\e[36m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "C"                                  # |C       - Foreground text bright cyan
        if(attributes["fg"] != "\e[96m")
          attributes["fg"] = "\e[96m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "w"                                  # |w - Foreground text white
        if(attributes["fg"] != "\e[37m")
          attributes["fg"] = "\e[37m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "W"                                  # |W - Foreground text white
        if(attributes["fg"] != "\e[97m")
          attributes["fg"] = "\e[97m"
          new_text << test_shell_add(attributes, attributes["fg"])
        end
      when "n", "N"                             # |n or |N - Foreground text normal
        attributes["fg"] = "\e[39m"
        new_text << test_shell_add(attributes, attributes["fg"])
      when "O"                                  # |O - Box mode off
        attributes["box"] = -1
      when "o"                                  # |o - Box mode 0
        attributes["box"] = 0
      when "-"                                  # |- - Box mode 1
        if(attributes["box_mode"] == true)
          attributes["box"] = 1
        else                                    # We didn"t find the next character
          attributes["found"] = false
        end
      when "="                                  # |= - Box mode 2
        if(attributes["box_mode"] == true)
          attributes["box"] = 2
        else                                    # We didn"t find the next character
          attributes["found"] = false
        end
      when "{"                                  # center
        attributes["center_capture"] = true
      when ";"                                  # extend to end column with spaces
        spaces = attributes["end"] - attributes["position"]
        spaces.times do
          new_text << " "
        end
      when "]"                                  # |]0-9* - end column number
        attributes["end_capture"] = true
      when "["                                  # |[emoji]
        attributes["emoji_capture"] = true
      when "("                                  # |(variable) or |(variable=Some value)
        attributes["variable_capture"] = true
      when ")"                                  # |)Right Aligned
        attributes["right_capture"] = true
      when "\\"                                 # |\       - Escape mode
        attributes["escape"] = true
      when "$"                                  # |$       - Toggle shell prompt mode
        if(attributes["shell_prompt"] == true)
          attributes["shell_prompt"] = false
        else
          attributes["shell_prompt"] = true
        end
      else                                      # We didn"t find the next character
        attributes["found"] = false
      end
    elsif(character == "\\")
      attributes["escape"] = true
    else                                        # We didn"t find the next character
      attributes["found"] = false
    end
    if(attributes["found"] == false)
      if(character == "0")                      # |10+
        if(attributes["num"] > 0)
          attributes["num"] *= 10
        end
      elsif(character >= "1" && character <= "9")  # |1+ through |9+
        if(attributes["num"] > 0)
          attributes["num"] *= 10
        end
        attributes["num"] += character.to_i
      else
        if(attributes["num"] <= 0)              # No replacement found
          new_text << "|" + character
        else                                    # Repeat number replacement found
          if(attributes["box"] == 1)
            attributes["num"].times do
              new_text << process_box_one_replace(character)
            end
            attributes["num"] = 0
          elsif(attributes["box"] == 2)
            attributes["num"].times do
              new_text << process_box_two_replace(character)
            end
            attributes["num"] = 0
          else
            attributes["num"].times do
              new_text << character
            end
            attributes["num"] = 0
          end
        end
        attributes["pipe"] = false
      end
    elsif(attributes["escape"] == false)
      attributes["pipe"] = false
    end
  end

  def process_ampersanded_character(character, new_text, attributes)
    case character
    when "#"                                    # &#RRGGBB
      attributes["color_capture"] = 1
      return
    when "P", "p"                               # |P or |p - 2 character hex format color (256 colors)
      attributes["palette_capture"] = 1
      return
    when "w"                                    # &w - Background white
      if(attributes["bg"] != "\e[47m")
        attributes["bg"] = "\e[47m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "W"                                    # &W - Background white
      if(attributes["bg"] != "\e[107m")
        attributes["bg"] = "\e[107m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "c"                                    # &c - Background cyan
      if(attributes["bg"] != "\e[46m")
        attributes["bg"] = "\e[46m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "C"                                    # &C - Background cyan
      if(attributes["bg"] != "\e[106m")
        attributes["bg"] = "\e[106m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "m"                                    # &m - Background magenta
      if(attributes["bg"] != "\e[45m")
        attributes["bg"] = "\e[45m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "M"                                    # &M - Background magenta
      if(attributes["bg"] != "\e[105m")
        attributes["bg"] = "\e[105m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "b"                                    # &b - Background blue
      if(attributes["bg"] != "\e[44m")
        attributes["bg"] = "\e[44m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "B"                                    # &B - Background blue
      if(attributes["bg"] != "\e[104m")
        attributes["bg"] = "\e[104m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "y"                                    # &y - Background yellow (brown)
      if(attributes["bg"] != "\e[43m")
        attributes["bg"] = "\e[43m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "Y"                                    # &Y - Background yellow (brown)
      if(attributes["bg"] != "\e[103m")
        attributes["bg"] = "\e[103m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "g"                                    # &g - Background green
      if(attributes["bg"] != "\e[42m")
        attributes["bg"] = "\e[42m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "G"                                    # &G - Background green
      if(attributes["bg"] != "\e[102m")
        attributes["bg"] = "\e[102m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "r"                                    # &r - Background red
      if(attributes["bg"] != "\e[41m")
        attributes["bg"] ="\e[41m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "R"                                    # &R - Background red
      if(attributes["bg"] != "\e[101m")
        attributes["bg"] ="\e[101m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "k"                                     # &k - Background black
      if(attributes["bg"] != "\e[40m")
        attributes["bg"] = "\e[40m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "K"                                     # &K - Background black
      if(attributes["bg"] != "\e[100m")
        attributes["bg"] = "\e[100m"
        new_text << test_shell_add(attributes, attributes["bg"])
      end
    when "n", "N"                               # &n or &N - Background normal
      attributes["bg"] = "\e[49m"
      new_text << test_shell_add(attributes, attributes["bg"])
    else
      new_text << "&" + character
    end
    attributes["ampersand"] = false
  end

  def process_box_zero_replace(character)
    case character
    when "["
      "+"
    when "]"
      "+"
    when "-"
      "-"
    when "!"
      "|"
    when ">"
      "+"
    when "<"
      "+"
    when "+"
      "+"
    when "{"
      "+"
    when "}"
      "+"
    when "v"
      "+"
    when "^"
      "+"
    else
      character
    end
  end

  def process_box_one_replace(character)
    case character
    when "["
      "╭"
    when "]"
      "╮"
    when "-"
      "─"
    when "!"
      "│"
    when ">"
      "├"
    when "<"
      "┤"
    when "+"
      "┼"
    when "{"
      "╰"
    when "}"
      "╯"
    when "v"
      "┬"
    when "^"
      "┴"
    else
      character
    end
  end

  def process_box_two_replace(character)
    case character
    when "["
      "╔"
    when "]"
      "╗"
    when "-"
      "═"
    when "!"
      "║"
    when ">"
      "╠"
    when "<"
      "╣"
    when "+"
      "╬"
    when "{"
      "╚"
    when "}"
      "╝"
    when "v"
      "╦"
    when "^"
      "╩"
    else
      character
    end
  end

  def process_box_three_replace(character)    # currently unused
    case character
    when "["
      "┌"
    when "]"
      "┐"
    when "-"
      "─"
    when "!"
      "│"
    when ">"
      "├"
    when "<"
      "┤"
    when "+"
      "┼"
    when "{"
      "└"
    when "}"
      "┘"
    when "v"
      "┬"
    when "^"
      "┴"
    else
      character
    end
  end
end
