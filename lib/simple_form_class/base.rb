module SimpleFormClass
  class Base

    MANDATORY_OWNER_METHODS = [ :attributes, :attributes=, :valid?, :save ]

    extend ActiveModel::Callbacks
    extend ActiveModel::Naming
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Serialization # TODO: remove?
    include ActiveModel::Naming if defined?(ActiveModel::Naming)

    define_model_callbacks :save, :initialize, :validation

    attr_accessor :params
    alias_method  :attributes, :params

    attr_accessor :options


    def initialize(params = nil, options = {})
      run_callbacks :initialize do
        @params = params || {}
        @options = options

        yield self if block_given?

        check_if_sane_owners!
        self.attributes = @params
      end
    end

    #yes, this method is needed, form breaks without it
    #check why later
    def persisted?
      false
    end

    # keep this before other validators, this will make sure all owners have been
    # valid?-ated so their errors.messages is present
    validate :delegate_validators_from_owners

    def self.field field_name, options = {}
      add_owner options[:owner]

      @fields ||= {}
      @fields[field_name] = options

      if options[:owner] == :self
        attr_accessor field_name
      else
        delegate field_name, "#{field_name}=", :to => options[:owner], :null => false
      end
    end

    # will require owner to be valid in order for form to be valid
    def self.validates_owner owner, options = {}
      validates_with SimpleFormClass::OwnerValidator, options.merge(owner: owner)
    end

    def self.human_attribute_name attribute, *args, &block
      field = fields[attribute.to_s.to_sym] || {}
      if field[:localized_by]
        field[:localized_by].constantize.human_attribute_name attribute, *args, &block
      else
        super(attribute, *args, &block)
      end
    end

    def self.owners
      @owners ||= []
      @owners = @owners_setup.keys + superclass.owners if superclass.respond_to? :owners
      @owners.uniq
    end

    def self.fields
      @fields ||= {}
      @fields.merge! superclass.fields if superclass.respond_to? :fields
      @fields
    end

    def options
      @options || {}
    end

    def owners(*args)
      owner_hash(*args).values.compact
    end

    def self.fields_for_owner owner
      fields.reject{|k,v| not v[:owner] == owner}.keys
    end

    def self.permitted_fields_for_owner owner
      fields.reject{|k,v| not (v[:owner] == owner and v[:write])}.keys
    end

    def save(*args)
      local_options = args.last.is_a?(Hash) ? args.last : {}
      validate = local_options.has_key?(:validate) ? local_options[:validate] : true

      if validate
        return false unless valid?
      end

      ActiveRecord::Base.transaction do
        run_callbacks :save do
          not owners(except_self: true).map{ |owner| owner.save(*args) }.include?(false)
        end
      end
    end

    def save!
      save || raise(ActiveRecord::RecordInvalid.new(self))
    end

    def self.add_owner owner, options = {}
      @owners_setup ||= {}
      attr_accessor owner unless @owners_setup.keys.include? owner
      
      @owners_setup[owner] ||= {}
      @owners_setup[owner].merge! options

    end

    def attributes=(attributes)
      self.class.owners.each do |owner|
        owners_hash = attributes_for_owner owner, attributes
        owners_attribute_setter = owner == :self ? :private_attributes= : :attributes=

        get_owner(owner).send(
          owners_attribute_setter,
          if defined?(ActionController::Parameters) && owners_hash.is_a?(ActionController::Parameters)
            owners_hash.permit(
              *self.class.permitted_fields_for_owner(owner)
            )
          else
            owners_hash
          end
        )
      end
    end

    
    private


    def delegate_validators_from_owners
      self.class.owners.each do |owner_sym|
        next if owner_sym == :self

        owner = send owner_sym
        if owner && !owner.valid?
          delegate_owner_error_messages_to_self owner
        end
      end
    end

    def delegate_owner_error_messages_to_self owner
      owner.errors.messages.each do |attribute, messages|
        next unless self.class.fields.has_key? attribute

        messages.each do |message|
          errors.add(attribute, message)
        end
      end
    end

    def attributes_for_owner owner, attributes = attributes
      attributes.slice(*self.class.fields_for_owner(owner))
    end

    def get_owner(owner)
      if owner == :self
        self
      else
        send(owner)
      end
    end

    def private_attributes=(attributes)
      attributes.each do |k,v|
        send("#{k}=", v)
      end
    end

    def owner_hash(options = {})
      #  options[:except_self]

      Hash[
        self.class.owners.map do |owner_sym|
          [
            owner_sym,
            if owner_sym == :self and options[:except_self]
              nil
            else
              get_owner owner_sym
            end
          ]
        end
      ]
    end

    def check_if_sane_owners!
      owner_hash.each do |owner_sym, owner|
        missing_expected_method = MANDATORY_OWNER_METHODS.detect{ |method| not owner.respond_to? method, true }

        if missing_expected_method
          raise InvalidOwner, "owner '#{owner_sym}' thas is of class #{owner.class} should behave like an ActiveModel object, but it doesn't respond to ##{missing_expected_method}"
        end
      end
    end

    protected

    def run_validations_with_validation_callback!(*args, &block)
      run_callbacks :validation do
        run_validations_without_validation_callback!(*args, &block)
        true
      end
      errors.empty?
    end
    alias_method_chain :run_validations!, :validation_callback


  end
end
