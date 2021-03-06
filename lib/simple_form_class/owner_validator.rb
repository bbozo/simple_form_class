module SimpleFormClass
  class OwnerValidator < ActiveModel::Validator

    def validate(record)
      owner_sym = options[:owner]
      owner = record.send(owner_sym)
      
      # Rails 3.0 have error_messages, Rails > 3.0 have errors.messages
      error_messages = ::Rails.version < "3.1" ? owner.errors.full_messages :
        owner.errors.messages

      unless error_messages.empty?
        unless SimpleFormClass.legacy_owner_validation
          record.errors.add(owner_sym, "is invalid due to #{error_messages}")
        else
          record.errors.add(:base, "#{owner_sym.to_s} is invalid due to #{error_messages}")
        end
      end
    end

  end
end
