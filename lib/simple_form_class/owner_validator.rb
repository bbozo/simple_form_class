module SimpleFormClass
  class OwnerValidator < ActiveModel::Validator

    def validate(record)
      owner_sym = options[:owner]
      owner = record.send(owner_sym)

      unless owner.errors.messages.empty?
        record.errors.add(owner_sym, "is invalid due to #{owner.errors.messages}")
      end
    end

  end
end
