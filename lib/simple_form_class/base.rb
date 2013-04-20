module SimpleFormClass
  class Base

    MANDATORY_OWNER_METHODS = [ :attributes, :attributes=, :valid?, :save ]

    extend ActiveModel::Callbacks
    extend ActiveModel::Naming
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Serialization # TODO: remove?

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

    validate :owners_must_be_valid

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


    def self.owners
      @owners ||= []
      @owners = @owners + superclass.owners if superclass.respond_to? :owners
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
      validate = options.has_key?(:validate) ? options[:validate] : true

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

    def self.add_owner owner
      @owners ||= []

      unless @owners.include? owner
        @owners << owner

        attr_accessor owner
      end
    end

    
    private


    def owners_must_be_valid
      self.class.owners.each do |owner_sym|
        next if owner_sym == :self

        owner = send owner_sym
        unless owner.valid?
          errors.add(:base, "#{owner_sym} of class #{owner.class.to_s} is invalid")
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

    def attributes=(attributes)
      self.class.owners.each do |owner|
        owners_hash = attributes_for_owner owner, attributes
        owners_attribute_setter = owner == :self ? :private_attributes= : :attributes=

        get_owner(owner).send(
          owners_attribute_setter,
          if owners_hash.is_a? ActionController::Parameters
            owners_hash.permit(
              *self.class.permitted_fields_for_owner(owner)
            )
          else
            owners_hash
          end
        )
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
      end
      errors.empty?
    end
    alias_method_chain :run_validations!, :validation_callback


  end
end
