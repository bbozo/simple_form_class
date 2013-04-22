module SimpleFormClass
  class Mock

    # returns hash with benefits of OpenStruct, certain keys will be treated like
    # accessing of attribute accessors and will be hidden from the hash, this is
    # used when you want the hash to carry some kind of additional context, for
    # example:
    #
    #  class TransactionParamsHash < SimpleFormClass::Mock.new(:t); end
    #
    #  def build_member_card_transaction_hash(options = {})
    #    t = FactoryGirl.build(:transaction_with_card, options)
    #    TransactionParamsHash.new(
    #      :t => t,
    #      :amount_money => t.amount_money,
    #      :currency => t.currency,
    #      :cvv => t.cvv,
    #      :user_card_id => t.user_card_id
    #    )
    #  end
    #
    # In this example the method returns a parameter hash for a transaction,
    # the :t key must not be inside or we'll face an attribute unknown exception,
    # but we do want the hash to have reference of the object that created it
    # because FactoryGirl built more attributes then are present in the explicit
    # hash declaration.
    #
    # Also, all keys in the hash are automatically assigned getter and setter methods
    # with to_s, so it's usable as a FactoryGirl class for mocking params hashes,
    # example:
    #
    #  factory :card_deposit_form, :class => SimpleFormClass::Mock.new(:current_user, :pan) do
    #    # housekeeping
    #    current_user
    #
    #    # form
    #    amount_money  { Money.new(rand(20)+100, 'EUR') }
    #    cvv           123
    #    user_card_id  { |t| FactoryGirl.create(:user_card, :user => t.current_user, :pan => t.pan || random_pan).id }
    #  end

    def self.new(*args)
      Class.new(HashWithIndifferentAccess) do
        cattr_accessor :accessorized_keys

        self.accessorized_keys = args.map(&:to_s)
        accessorized_keys.each{ |arg| attr_accessor arg }

        def initialize(*args, &block)
          super(*args, &block)
          extract_all_keys_to_accessors
        end

        def []= key, value
          rv = super key, value
          extract_key_to_accessor key if self.class.accessorized_keys.include? key.to_s
          rv
        end

        def self.from_xml *args, &block
          new(super(*args, &block))
        end

        def method_missing(method, *args, &block)
          return self[method.to_s] if has_key?(method.to_s)
          return self[method.to_s.gsub(/=/, '')] = args.first if method.to_s =~ /=$/

          super(method, *args, &block)
        end

        def respond_to?(method, private = false)
          return true if has_key?(method.to_s) or method.to_s =~ /=$/
          super(method, private)
        end

        private

        define_method :extract_key_to_accessor do |key|
          self.send("#{key}=", self[key])
          self.delete key
        end

        define_method :extract_all_keys_to_accessors do
          args.each{ |arg| extract_key_to_accessor arg }
        end

      end
    end

  end
end
