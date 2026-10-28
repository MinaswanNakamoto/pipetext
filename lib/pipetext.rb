# Allow older versions of Ruby to respond to the require_relative method
if(!Kernel.respond_to?(:require_relative))
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative File.join("pipetext", "pipetext.rb")
