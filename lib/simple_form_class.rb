require "simple_form_class/version"

require "action_controller/base"
require "simple_form_class/base"
require "simple_form_class/mock"
require "simple_form_class/owner_validator"

module SimpleFormClass

  class InvalidOwner < ArgumentError; end

end
