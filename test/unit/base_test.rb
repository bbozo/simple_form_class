require 'test_helper'

class BaseTest < MiniTest::Spec

  # TODO: make the rake job work, bundle exec ruby -I lib -I test test/unit/*_test.rb

  class TestException < Exception; end

  NON_YIELD_CALLBACKS = [:before_save, :after_save, :before_initialize, :after_initialize,
    :before_validation, :after_validation
  ]
  YIELD_CALLBACKS = [:around_save, :around_initialize, :around_validation]
  CALLBACKS = NON_YIELD_CALLBACKS + YIELD_CALLBACKS

  context :callbacks do

    should "get triggered on class methods" do
      @class = Class.new(SimpleFormClass::Base) do

        attr_reader :callbacks

        def initialize
          @callbacks = []
          super
        end

        CALLBACKS.each do |callback|
          self.send(callback) do
            yield if block_given?
            @callbacks << callback
          end
        end
      end

      @dummy_instance = @class.new  # initialize callbacks
      assert_valid @dummy_instance, "test case setup problem, @dummy_instance is not valid"  # also, validation callbacks
      @dummy_instance.save          # save callbacks

      CALLBACKS.each do |callback|
        assert_includes @dummy_instance.callbacks, callback,
          "expected #{callback} to leave a trace in callbacks array, that didn't happen"
      end
    end

    context :validation do

      should "after_* still work if form is invalid" do
        @class = Class.new(SimpleFormClass::Base) do
          field :foo, owner: :self
          validates :foo, presence: true
          attr_reader :after_validation_happened
          after_validation :foo do
            @after_validation_happened = true
          end
        end
        Object.const_set("Klass#{@class.object_id}", @class)
        
        @dummy_instance = @class.new
        assert_invalid @dummy_instance, :foo, 'test case setup problem'

        assert @dummy_instance.after_validation_happened,
          'expected after_validation to get triggered'
      end

      context :repetition do

        setup do
          @class = Class.new(SimpleFormClass::Base) do
            field :foo, owner: :self
            attr_reader :before_validation_count
            attr_reader :validation_count
            attr_reader :after_validation_count

            before_validation { @before_validation_count = @before_validation_count.to_i + 1 }
            validate          { @validation_count = @validation_count.to_i + 1               }
            after_validation  { @after_validation_count = @after_validation_count.to_i + 1   }
          end
          Object.const_set("Klass#{@class.object_id}", @class)

          @dummy_instance = @class.new
        end

        should "get executed exactly once on save" do
          @dummy_instance.save
          assert_equal 1, @dummy_instance.before_validation_count, 'before validation count is off'
          assert_equal 1, @dummy_instance.validation_count,        'validation count is off'
          assert_equal 1, @dummy_instance.after_validation_count,  'after validation count is off'
        end

        should "get executed exactly once on valid?" do
          @dummy_instance.valid?
          assert_equal 1, @dummy_instance.before_validation_count, 'before validation count is off'
          assert_equal 1, @dummy_instance.validation_count,        'validation count is off'
          assert_equal 1, @dummy_instance.after_validation_count,  'after validation count is off'
        end

        should "get not get executed on save validate: false" do
          @dummy_instance.save validate: false
          assert_equal nil, @dummy_instance.before_validation_count, 'before validation count is off'
          assert_equal nil, @dummy_instance.validation_count,        'validation count is off'
          assert_equal nil, @dummy_instance.after_validation_count,  'after validation count is off'
        end

      end

    end

    should_eventually "get triggered on callback method override" do
      @class = Class.new(SimpleFormClass::Base) do

        attr_reader :callbacks

        def initialize
          @callbacks = []
          super
        end

        CALLBACKS.each do |callback|
          class_eval <<-RUBY
            def #{callback}
              yield if block_given?
              @callbacks << callback
            end
          RUBY
        end
      end

      @dummy_instance = @class.new  # initialize callbacks
      assert_valid @dummy_instance, "test case setup problem, @dummy_instance is not valid"  # also, validation callbacks
      @dummy_instance.save          # save callbacks

      CALLBACKS.each do |callback|
        assert_includes @dummy_instance.callbacks, callback,
          "expected #{callback} to leave a trace in callbacks array, that didn't happen"
      end
    end

  end

  context :owners do

    setup do
      @class = Class.new(SimpleFormClass::Base) do
        add_owner :test

        field :foo_test,  :owner => :foo
        field :self_test, :owner => :self
      end

      @dummy_instance = @class.new do |o|
        o.foo = Product.new
        o.test = Order.new
      end
    end

    should "behave like ActiveModel objects and raise otherwise" do
      assert_raises SimpleFormClass::InvalidOwner do
        @class.new do |o|
          o.test = Object.new
        end
      end
    end

    should "generate a proper owner hash" do
      owner_hash = @dummy_instance.send :owner_hash

      assert_kind_of Hash, owner_hash, "owner_hash is of wrong type"
      assert_equal [:test, :foo, :self], owner_hash.keys, "owner_hash has wrong keys"

      assert_kind_of Product, owner_hash[:foo], 'wrong class for :foo'
      assert_kind_of Order, owner_hash[:test], 'wrong class for :test'
      assert_equal @dummy_instance, owner_hash[:self], 'wrong instance for :self'
    end

  end


  context :field do

    setup do
      @class = Class.new(SimpleFormClass::Base) do
        field :self_foo, :owner => :self,  :write => true
        field :price,  :owner => :owner, :write => true

        field :self_boo, :owner => :self
        field :name,   :owner => :owner
      end

      @owner = Product.new

      @form = @class.new do |o|
        o.owner = @owner
      end
    end

    # NOTE: only mass assignment is squashed, not regular assignment

    should "work as attr_accessor on self regardless of write flag" do
      @form.self_foo = 10
      assert_equal 10, @form.self_foo, "expected self_foo to change state after setter"

      @form.self_boo = 11
      assert_equal 11, @form.self_boo, "expected self_boo to change state after setter"
    end

    should "work as delegator on owned regardless of write flag" do
      @form.price = 12
      assert_equal 12, @form.price,  "expected message to change state after setter on @form"
      assert_equal 12, @form.owner.price, "expected message to change state after setter on @form.owner"
      assert_equal 12, @owner.price, "expected message to change state after setter on @owner"

      @form.name = 13
      assert_equal 13, @form.name,  "expected params to change state after setter on @form"
      assert_equal 13, @form.owner.name, "expected params to change state after setter on @form.owner"
      assert_equal 13, @owner.name, "expected params to change state after setter on @owner"
    end

    context "mass assignment" do

      should "work on all attributes if not params.is_a? ActionController::Parameters" do
        params = { self_foo: 20, price: 21, self_boo: 22, name: 23 }
        assert_kind_of Hash, params, "test case setup problem, params is of wrong class"

        form = @class.new(params) do |o|
          o.owner = @owner
        end

        assert_equal 20, form.self_foo, "expected self_foo to get mass assigned"
        assert_equal 21, form.price,  "expected message to get mass assigned"

        assert_equal 22, form.self_boo, "expected self_boo to get mass assigned"
        assert_equal 23, form.name,   "expected params to get mass assigned"
      end

      should "filter attributes without write: true if params.is_a? ActionController::Parameters" do
        params = ActionController::Parameters.new(self_foo: 30, price: 31, self_boo: 32, name: 33)
        assert_kind_of ActionController::Parameters, params, "test case setup problem, params is of wrong class"

        form = @class.new(params) do |o|
          o.owner = @owner
        end

        assert_equal 30, form.self_foo, "expected self_foo to get mass assigned"
        assert_equal 31, form.price,  "expected message to get mass assigned"
        assert_equal nil, form.self_boo, "expected self_boo to get filtered out"
        assert_equal nil, form.name,   "expected params to get filtered out"
      end

    end

  end

  context :validators do

    setup do
      @class = Class.new(SimpleFormClass::Base) do
        field :self_foo, :owner => :self,  :write => true
        field :price,  :owner => :owner, :write => true
        attr_accessor :perform_owner_validation

        validates :self_foo, presence: true
        validates :price, numericality: true
        validates_owner :owner, if: :perform_owner_validation
      end
      Object.const_set("Klass#{@class.object_id}", @class)

      @owner = Product.new

      class << @owner
        attr_reader :validation_count
        validate :inc_valiation_count

        def inc_valiation_count
          @validation_count = @validation_count.to_i + 1
        end
      end

      @form = @class.new do |o|
        o.owner = @owner
      end
    end

    should "be set up correctly for tests, @owner" do
      assert_invalid @owner, :price, "test case setup problem"
    end

    should "delegate from owner to form" do
      assert_invalid @form, :price
    end

    should "be executed for local form validation chain" do
      assert_invalid @form, :self_foo
    end

    should "not get executed on owner when save validate: false" do
      @form.save validate: false
      assert_equal nil, @owner.validation_count, 'validation count is off'
    end

    should "get executed once on owner when valid?" do
      @form.valid?
      assert_equal 1, @owner.validation_count, 'validation count is off'
    end
    
    should "get executed once on owner when save" do
      @form.save
      assert_equal 1, @owner.validation_count, 'validation count is off'
    end

    context "with owner validations" do

      setup do
        @form.perform_owner_validation = true
      end

      should "be set up correctly for tests, @owner" do
        assert_invalid @owner, :price, "test case setup problem"
      end

      should "delegate from owner to form" do
        assert_invalid @form, :price
      end

      should "be executed for local form validation chain" do
        assert_invalid @form, :self_foo
      end

      should "not get executed on owner when save validate: false" do
        @form.save validate: false
        assert_equal nil, @owner.validation_count, 'validation count is off'
      end

      should "get executed once on owner when valid?" do
        @form.valid?
        assert_equal 1, @owner.validation_count, 'validation count is off'
      end

      should "get executed once on owner when save" do
        @form.save
        assert_equal 1, @owner.validation_count, 'validation count is off'
      end

    end

    context "owner validators" do

      setup do
        @form.attributes = {
          self_foo: 'foo',
          price: 15
        }
        @form.perform_owner_validation = true
      end

      should "be set up correctly" do
        @form.perform_owner_validation = false
        
        assert_valid @form, 'without owner validation @form should be valid'
      end

      should "validate its owners" do
        assert_invalid @form, :owner
      end

      should "be valid once owners are valid" do
        @owner.name = 'Foo'
        assert_valid @form
      end

    end

  end

  context :inheritancs do

    # TODO
    should_eventually :propagate_owners_to_subclass do; end
    should_eventually :propagate_fields_to_subclass do; end

    # TODO
    should_eventually :not_cumulatively_add_owners do; end # see #831
    should_eventually :not_cumulatively_add_fields do; end # see #831

  end


end