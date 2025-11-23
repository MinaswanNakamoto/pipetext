# frozen_string_literal: true

# Allow older versions of Ruby to respond to the require_relative method
if(!Kernel.respond_to?(:require_relative))
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'pipetext/version.rb'
require_relative 'pipetext/pipetext.rb'
require_relative 'pipetext/substitute_emoji_names.rb'
