ENV["RAILS_ENV"] = "test"
require File.expand_path('../dummy/config/environment', __FILE__)
require File.expand_path('../../lib/simple_form_class', __FILE__)

require "minitest/autorun"
require "minitest/unit"
require "minitest/rails/shoulda"



class MiniTest::Spec
  
  def assert_difference command, expected_delta, message = 'difference must be equal'
    rv = eval command
    yield
    delta = eval(command) - rv

    assert_equal expected_delta, delta, message
  end

  # asserts an object does not pass validation, for example:
  #
  # test for invalid on one and two attributes with no specific messages:
  #
  #   assert_invalid @user_card, :masked_pan, 'second user_card'
  #   assert_invalid @user_card, [:masked_pan, :hashed_pan], 'second user_card'
  #
  # test for invalid on one  and attributes with specific messages - please note
  # that validation messages are often used to configure display of certain messages
  # in the view layer, this is why using specific messages may lead to brittle
  # tests that result in false positive assertions after view layer changes
  #
  #   assert_invalid @user_card, {:masked_pan => 'has already been taken'}, 'second user_card'
  #   assert_invalid @user_card, {:masked_pan => 'has already been taken', :hashed_pan => 'is not a hash'}, 'second user_card'
  def assert_invalid object, errors, message = nil
    refute object.valid?, [message, 'expected to be invalid'].compact.join(': ')

    errors = [errors] unless errors.respond_to? :each

    errors.each do |attribute, error_message|
      assert object.errors.messages.has_key?(attribute),
        [message, "expected to have a validation error on #{attribute}, but got #{object.errors.messages}"].compact.join(': ')

      if error_message
        assert object.errors.messages[attribute].include?(error_message),
          [message, "expected to have a validation error for '#{error_message}' on #{attribute}, got #{object.errors.messages[attribute]}"].compact.join(': ')
      end
    end
  end

  # asserts an object is valid, for example:
  #
  #  assert_valid user_card, 'first user_card'
  #  c1.save # will always pass
  def assert_valid object, message = nil
    assert object.valid?, [message, "expected to be valid, got #{object.errors.messages}"].compact.join(': ')
  end
end