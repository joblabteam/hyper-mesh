module ActiveRecord

  module ClassMethods

    def base_class

      unless self < Base
        raise ActiveRecordError, "#{name} doesn't belong in a hierarchy descending from ActiveRecord"
      end

      if superclass == Base || superclass.abstract_class?
        self
      else
        superclass.base_class
      end

    end

    def abstract_class?
      defined?(@abstract_class) && @abstract_class == true
    end

    def primary_key
      base_class.instance_eval { @primary_key_value || :id }
    end

    def primary_key=(val)
     base_class.instance_eval {  @primary_key_value = val }
    end

    def inheritance_column
      base_class.instance_eval {@inheritance_column_value || "type"}
    end

    def inheritance_column=(name)
      base_class.instance_eval {@inheritance_column_value = name}
    end

    def model_name
      # TODO in reality should return ActiveModel::Name object, blah blah
      # an d this may be relavant for I18n, check hyper-i18n
      name
    end

    def find(id)
      base_class.instance_eval {ReactiveRecord::Base.find(self, primary_key, id)}
    end

    def find_by(opts = {})
      base_class.instance_eval {ReactiveRecord::Base.find(self, opts.first.first, opts.first.last)}
    end

    def enum(*args)
      # when we implement schema validation we should also implement value checking
    end

    def serialize(attr, *args)
      ReactiveRecord::Base.serialized?[self][attr] = true
    end

    # ignore any of these methods if they get called on the client.   This list should be trimmed down to include only
    # methods to be called as "macros" such as :after_create, etc...
    SERVER_METHODS = [
      :attribute_type_decorations, :defined_enums, :_validators, :timestamped_migrations, :lock_optimistically, :lock_optimistically=,
      :local_stored_attributes=, :lock_optimistically?, :attribute_aliases?, :attribute_method_matchers?, :defined_enums?,
      :has_many_without_reactive_record_add_changed_method, :has_many_with_reactive_record_add_changed_method,
      :belongs_to_without_reactive_record_add_changed_method, :belongs_to_with_reactive_record_add_changed_method,
      :cache_timestamp_format, :composed_of_with_reactive_record_add_changed_method, :schema_format, :schema_format=,
      :error_on_ignored_order_or_limit, :error_on_ignored_order_or_limit=, :timestamped_migrations=, :dump_schema_after_migration,
      :dump_schema_after_migration=, :dump_schemas, :dump_schemas=, :warn_on_records_fetched_greater_than=,
      :belongs_to_required_by_default, :default_connection_handler, :connection_handler=, :default_connection_handler=,
      :skip_time_zone_conversion_for_attributes, :skip_time_zone_conversion_for_attributes=, :time_zone_aware_types,
      :time_zone_aware_types=, :protected_environments, :skip_time_zone_conversion_for_attributes?, :time_zone_aware_types?,
      :partial_writes, :partial_writes=, :composed_of_without_reactive_record_add_changed_method, :logger, :partial_writes?,
      :after_initialize, :record_timestamps, :record_timestamps=, :after_find, :after_touch, :before_save, :around_save,
      :belongs_to_required_by_default=, :default_connection_handler?, :before_create, :around_create, :before_update, :around_update,
      :after_save, :before_destroy, :around_destroy, :after_create, :after_destroy, :after_update, :_validation_callbacks,
      :_validation_callbacks?, :_validation_callbacks=, :_initialize_callbacks, :_initialize_callbacks?, :_initialize_callbacks=,
      :_find_callbacks, :_find_callbacks?, :_find_callbacks=, :_touch_callbacks, :_touch_callbacks?, :_touch_callbacks=, :_save_callbacks,
      :_save_callbacks?, :_save_callbacks=, :_create_callbacks, :_create_callbacks?, :_create_callbacks=, :_update_callbacks,
      :_update_callbacks?, :_update_callbacks=, :_destroy_callbacks, :_destroy_callbacks?, :_destroy_callbacks=, :record_timestamps?,
      :_synchromesh_scope_args_check, :pre_synchromesh_scope, :pre_synchromesh_default_scope, :do_not_synchronize, :do_not_synchronize?,
      :logger=, :maintain_test_schema, :maintain_test_schema=, :scope, :time_zone_aware_attributes, :time_zone_aware_attributes=,
      :default_timezone, :default_timezone=, :_attr_readonly, :warn_on_records_fetched_greater_than, :configurations, :configurations=,
      :_attr_readonly?, :table_name_prefix=, :table_name_suffix=, :schema_migrations_table_name=, :internal_metadata_table_name,
      :internal_metadata_table_name=, :primary_key_prefix_type, :_attr_readonly=, :pluralize_table_names=, :protected_environments=,
      :ignored_columns=, :ignored_columns, :index_nested_attribute_errors, :index_nested_attribute_errors=, :primary_key_prefix_type=,
      :table_name_prefix?, :table_name_suffix?, :schema_migrations_table_name?, :internal_metadata_table_name?, :protected_environments?,
      :pluralize_table_names?, :ignored_columns?, :store_full_sti_class, :store_full_sti_class=, :nested_attributes_options,
      :nested_attributes_options=, :store_full_sti_class?, :default_scopes, :default_scope_override, :default_scopes=, :default_scope_override=,
      :nested_attributes_options?, :cache_timestamp_format=, :cache_timestamp_format?, :reactive_record_association_keys, :_validators=,
      :has_many, :belongs_to, :composed_of, :belongs_to_without_reactive_record_add_is_method, :_rollback_callbacks, :_commit_callbacks,
      :_before_commit_callbacks, :attribute_type_decorations=, :_commit_callbacks=, :_commit_callbacks?, :_before_commit_callbacks?,
      :_before_commit_callbacks=, :_rollback_callbacks=, :_before_commit_without_transaction_enrollment_callbacks?,
      :_before_commit_without_transaction_enrollment_callbacks=, :_commit_without_transaction_enrollment_callbacks,
      :_commit_without_transaction_enrollment_callbacks?, :_commit_without_transaction_enrollment_callbacks=, :_rollback_callbacks?,
      :_rollback_without_transaction_enrollment_callbacks?, :_rollback_without_transaction_enrollment_callbacks=,
      :_rollback_without_transaction_enrollment_callbacks, :_before_commit_without_transaction_enrollment_callbacks, :aggregate_reflections,
      :_reflections=, :aggregate_reflections=, :pluralize_table_names, :public_columns_hash, :attributes_to_define_after_schema_loads,
      :attributes_to_define_after_schema_loads=, :table_name_suffix, :schema_migrations_table_name, :attribute_aliases,
      :attribute_method_matchers, :connection_handler, :attribute_aliases=, :attribute_method_matchers=, :_validate_callbacks,
      :_validate_callbacks?, :_validate_callbacks=, :_validators?, :_reflections?, :aggregate_reflections?, :include_root_in_json,
      :_reflections, :include_root_in_json=, :include_root_in_json?, :local_stored_attributes, :default_scope, :table_name_prefix,
      :attributes_to_define_after_schema_loads?, :attribute_type_decorations?, :defined_enums=, :suppress, :has_secure_token,
      :generate_unique_secure_token, :store, :store_accessor, :_store_accessors_module, :stored_attributes, :reflect_on_aggregation,
      :reflect_on_all_aggregations, :_reflect_on_association, :reflect_on_all_associations, :clear_reflections_cache, :reflections,
      :reflect_on_association, :reflect_on_all_autosave_associations, :no_touching, :transaction, :after_commit, :after_rollback, :before_commit,
      :before_commit_without_transaction_enrollment, :after_create_commit, :after_update_commit, :after_destroy_commit,
      :after_commit_without_transaction_enrollment, :after_rollback_without_transaction_enrollment, :raise_in_transactional_callbacks,
      :raise_in_transactional_callbacks=, :accepts_nested_attributes_for, :has_secure_password, :has_one, :has_and_belongs_to_many,
      :before_validation, :after_validation, :serialize, :primary_key, :dangerous_attribute_method?, :get_primary_key, :quoted_primary_key,
      :define_method_attribute, :reset_primary_key, :primary_key=, :define_method_attribute=, :attribute_names, :initialize_generated_modules,
      :column_for_attribute, :define_attribute_methods, :undefine_attribute_methods, :instance_method_already_implemented?, :method_defined_within?,
      :dangerous_class_method?, :class_method_defined_within?, :attribute_method?, :has_attribute?, :generated_attribute_methods,
      :attribute_method_prefix, :attribute_method_suffix, :attribute_method_affix, :attribute_alias?, :attribute_alias, :define_attribute_method,
      :update_counters, :locking_enabled?, :locking_column, :locking_column=, :reset_locking_column, :decorate_attribute_type,
      :decorate_matching_attribute_types, :attribute, :define_attribute, :reset_counters, :increment_counter, :decrement_counter,
      :validates_absence_of, :validates_length_of, :validates_size_of, :validates_presence_of, :validates_associated, :validates_uniqueness_of,
      :validates_acceptance_of, :validates_confirmation_of, :validates_exclusion_of, :validates_format_of, :validates_inclusion_of,
      :validates_numericality_of, :define_callbacks, :normalize_callback_params, :__update_callbacks, :get_callbacks, :set_callback,
      :set_callbacks, :skip_callback, :reset_callbacks, :deprecated_false_terminator, :define_model_callbacks, :validate, :validators,
      :validates_each, :validates_with, :clear_validators!, :validators_on, :validates, :_validates_default_keys, :_parse_validates_options,
      :validates!, :_to_partial_path, :sanitize, :sanitize_sql, :sanitize_conditions, :quote_value, :sanitize_sql_for_conditions, :sanitize_sql_array,
      :sanitize_sql_for_assignment, :sanitize_sql_hash_for_assignment, :sanitize_sql_for_order, :expand_hash_conditions_for_aggregates, :sanitize_sql_like,
      :replace_named_bind_variables, :replace_bind_variables, :raise_if_bind_arity_mismatch, :replace_bind_variable, :quote_bound_value, :all,
      :default_scoped, :valid_scope_name?, :scope_attributes?, :before_remove_const, :ignore_default_scope?, :unscoped, :build_default_scope,
      :evaluate_default_scope, :ignore_default_scope=, :current_scope, :current_scope=, :scope_attributes, :base_class, :abstract_class?,
      :finder_needs_type_condition?, :sti_name, :descends_from_active_record?, :abstract_class, :compute_type, :abstract_class=, :table_name, :columns,
      :table_exists?, :columns_hash, :column_names, :attribute_types, :prefetch_primary_key?, :sequence_name, :quoted_table_name, :_default_attributes,
      :type_for_attribute, :inheritance_column, :attributes_builder, :inheritance_column=, :reset_table_name, :table_name=, :reset_column_information,
      :full_table_name_prefix, :full_table_name_suffix, :reset_sequence_name, :sequence_name=, :next_sequence_value, :column_defaults, :content_columns,
      :readonly_attributes, :attr_readonly, :create, :create!, :instantiate, :find, :type_caster, :arel_table, :find_by, :find_by!, :initialize_find_by_cache,
      :generated_association_methods, :arel_engine, :arel_attribute, :predicate_builder, :collection_cache_key, :relation_delegate_class,
      :initialize_relation_delegate_cache, :enum, :collecting_queries_for_explain, :exec_explain, :i18n_scope, :lookup_ancestors, :human_attribute_name,
      :references, :uniq, :maximum, :none, :exists?, :second, :limit, :order, :eager_load, :update, :delete_all, :destroy, :ids, :many?, :pluck, :third,
      :delete, :fourth, :fifth, :forty_two, :second_to_last, :third_to_last, :preload, :sum, :take!, :first!, :last!, :second!, :offset, :select, :fourth!,
      :third!, :third_to_last!, :fifth!, :where, :first_or_create, :second_to_last!, :forty_two!, :first, :having, :any?, :one?, :none?, :find_or_create_by,
      :from, :first_or_create!, :first_or_initialize, :except, :find_or_create_by!, :find_or_initialize_by, :includes, :destroy_all, :update_all, :or,
      :find_in_batches, :take, :joins, :find_each, :last, :in_batches, :reorder, :group, :left_joins, :left_outer_joins, :rewhere, :readonly, :create_with,
      :distinct, :unscope, :calculate, :average, :count_by_sql, :minimum, :lock, :find_by_sql, :count, :cache, :uncached, :connection, :connection_pool,
      :establish_connection, :connected?, :clear_cache!, :clear_reloadable_connections!, :connection_id, :connection_config, :clear_all_connections!,
      :remove_connection, :connection_specification_name, :connection_specification_name=, :retrieve_connection, :connection_id=, :clear_active_connections!,
      :sqlite3_connection, :direct_descendants, :benchmark, :model_name, :with_options, :attr_protected, :attr_accessible
    ]

    def method_missing(name, *args, &block)
      # TODO use start_with? instead of regexp
      if args.count == 1 && name =~ /^find_by_/ && !block
        find_by(name.gsub(/^find_by_/, "") => args[0])
      elsif !SERVER_METHODS.include?(name)
        raise "#{self.name}.#{name}(#{args}) (called class method missing)"
      end
    end

    def abstract_class=(val)
      @abstract_class = val
    end

    def scope(name, body)
      singleton_class.send(:define_method, name) do | *args |
        args = (args.count == 0) ? name : [name, *args]
        ReactiveRecord::Base.class_scopes(self)[args] ||= ReactiveRecord::Collection.new(self, nil, nil, self, args)
      end
      singleton_class.send(:define_method, "#{name}=") do |collection|
        ReactiveRecord::Base.class_scopes(self)[name] = collection
      end
    end

    def all
      ReactiveRecord::Base.class_scopes(self)[:all] ||= ReactiveRecord::Collection.new(self, nil, nil, self, "all")
    end

    def all=(collection)
      ReactiveRecord::Base.class_scopes(self)[:all] = collection
    end

    # def server_methods(*methods)
    #   methods.each do |method|
    #     define_method(method) do |*args|
    #       if args.count == 0
    #         @backing_record.reactive_get!(method, :initialize)
    #       else
    #         @backing_record.reactive_get!([[method]+args], :initialize)
    #       end
    #     end
    #     define_method("#{method}!") do |*args|
    #       if args.count == 0
    #         @backing_record.reactive_get!(method, :force)
    #       else
    #         @backing_record.reactive_get!([[method]+args], :force)
    #       end
    #     end
    #   end
    # end
    #
    # alias_method :server_method, :server_methods

    [:belongs_to, :has_many, :has_one].each do |macro|
      define_method(macro) do |*args| # is this a bug in opal?  saying name, scope=nil, opts={} does not work!
        name = args.first
        define_method(name) { @backing_record.reactive_get!(name, nil) }
        define_method("#{name}=") do |val|
          @backing_record.reactive_set!(name, backing_record.convert(name, val).itself)
        end
        opts = (args.count > 1 and args.last.is_a? Hash) ? args.last : {}
        Associations::AssociationReflection.new(self, macro, name, opts)
      end
    end

    def composed_of(name, opts = {})
      Aggregations::AggregationReflection.new(base_class, :composed_of, name, opts)
      define_method(name) { @backing_record.reactive_get!(name, nil) }
      define_method("#{name}=") do |val|
        @backing_record.reactive_set!(name, backing_record.convert(name, val))
      end
    end

    def column_names
      ReactiveRecord::Base.public_columns_hash.keys
    end

    def columns_hash
      ReactiveRecord::Base.public_columns_hash[name] || {}
    end

    def server_methods
      @server_methods ||= {}
    end

    def server_method(name, default: nil)
      server_methods[name] = { default: default }
      define_method(name) do |*args|
        vector = args.count.zero? ? name : [[name]+args]
        @backing_record.reactive_get!(vector, nil)
      end
      define_method("#{name}!") do |*args|
        vector = args.count.zero? ? name : [[name]+args]
        @backing_record.reactive_get!(vector, true)
      end
    end

    def define_attribute_methods
      columns_hash.keys.each do |name|
        next if name == :id
        define_method(name) { @backing_record.reactive_get!(name, nil) }
        define_method("#{name}!") { @backing_record.reactive_get!(name, true) }
        define_method("#{name}=") do |val|
          @backing_record.reactive_set!(name, backing_record.convert(name, val))
        end
        define_method("#{name}_changed?") { @backing_record.changed?(name) }
      end
    end

    def _react_param_conversion(param, opt = nil)
      param = Native(param)
      param = JSON.from_object(param.to_n) if param.is_a? Native::Object
      result = if param.is_a? self
        param
      elsif param.is_a? Hash
        if opt == :validate_only
          klass = ReactiveRecord::Base.infer_type_from_hash(self, param)
          klass == self or klass < self
        else
          if param[primary_key]
            target = find(param[primary_key])
          else
            target = new
          end
          associations = reflect_on_all_associations
          param = param.collect do |key, value|
            assoc = reflect_on_all_associations.detect do |assoc|
              assoc.association_foreign_key == key
            end
            if assoc
              if value
                [assoc.attribute, {id: [value], type: [nil]}]
              else
                [assoc.attribute, [nil]]
              end
            else
              [key, [value]]
            end
          end

          # We do want to be doing something like this, but this breaks other stuff...
          #
          # ReactiveRecord::Base.load_data do
          #   ReactiveRecord::ServerDataCache.load_from_json(Hash[param], target)
          # end

          ReactiveRecord::ServerDataCache.load_from_json(Hash[param], target)
          target
        end
      else
        nil
      end
      result
    end

  end

end
