class MockTest < MiniTest::Spec

  setup do
    @mock_class = SimpleFormClass::Mock.new(:hidden)
    @mock = @mock_class.new("hidden" => "foo", "shown" => "bar")
  end

  should "hide hidden hash keys from hash representation" do
    assert_equal ({"shown" => "bar"}), @mock
  end

  should "present getters and setters for shown keys" do
    assert @mock.respond_to? :shown, "mock should respond to #shown"
    assert @mock.respond_to? :shown=, "mock should respond to #shown="

    assert_equal :new_shown, ( @mock.shown = :new_shown ),
      "setter shown= should return the new value"
    assert_equal :new_shown, @mock.shown, "getter shown should return the new value"

    assert_equal :new_shown, @mock[:shown],
      "hash representation needs to mirror the getter/setter state"
  end

  should "present getters and setters for hidden keys" do
    assert @mock.respond_to? :hidden, "mock should respond to #hidden"
    assert @mock.respond_to? :hidden=, "mock should respond to #hidden="

    assert_equal :new_hidden, ( @mock.hidden = :new_hidden ),
      "setter hidden= should return the new value"
    assert_equal :new_hidden, @mock.hidden, "getter hidden should return the new value"
  end


end
