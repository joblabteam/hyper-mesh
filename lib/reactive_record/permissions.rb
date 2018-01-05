class ActiveRecord::Base

  attr_accessor :acting_user

  def view_permitted?(attribute)
    Hyperloop::InternalPolicy.accessible_attributes_for(self, acting_user).include? attribute.to_sym
  end

  def create_permitted?
    false
  end

  def update_permitted?
    false
  end

  def destroy_permitted?
    false
  end

  def only_changed?(*attributes)
    (self.attributes.keys + self.class.reactive_record_association_keys).each do |key|
      return false if self.send("#{key}_changed?") and !attributes.include? key
    end
    true
  end

  def none_changed?(*attributes)
    attributes.each do |key|
      return false if self.send("#{key}_changed?")
    end
    true
  end

  def any_changed?(*attributes)
    attributes.each do |key|
      return true if self.send("#{key}_changed?")
    end
    false
  end

  def all_changed?(*attributes)
    attributes.each do |key|
      return false unless self.send("#{key}_changed?")
    end
    true
  end

  class << self

    attr_reader :reactive_record_association_keys

    [:has_many, :belongs_to, :composed_of].each do |macro|
      define_method "#{macro}_with_reactive_record_add_changed_method".to_sym do |attr_name, *args, &block|
        define_method "#{attr_name}_changed?".to_sym do
          instance_variable_get "@reactive_record_#{attr_name}_changed".to_sym
        end
        (@reactive_record_association_keys ||= []) << attr_name
        send "#{macro}_without_reactive_record_add_changed_method".to_sym, attr_name, *args, &block
      end
      alias_method "#{macro}_without_reactive_record_add_changed_method".to_sym, macro
      alias_method macro, "#{macro}_with_reactive_record_add_changed_method".to_sym
    end

    alias belongs_to_without_reactive_record_add_is_method belongs_to

    def belongs_to(attr_name, scope = nil, options = {})
      define_method "#{attr_name}_is?".to_sym do |model|
        send(options[:foreign_key] || "#{attr_name}_id") == model.id
      end
      belongs_to_without_reactive_record_add_is_method(attr_name, scope, options)
    end
  end


  def check_permission_with_acting_user(user, permission, *args)
    old = acting_user
    self.acting_user = user
    if self.send(permission, *args)
      self.acting_user = old
      self
    else
      raise ReactiveRecord::AccessViolation, "for #{permission}(#{args})"
    end
  end

end

class ActionController::Base

  def acting_user
  end

end
