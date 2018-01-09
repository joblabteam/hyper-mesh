module ReactiveRecord

  # the point is to collect up a all records needed, with whatever attributes were required + primary key, and inheritance column
  # or get all scope arrays, with the record ids

  # the incoming vector includes the terminal method

  # output is a hash tree of the form
  # tree ::= {method => tree | [value]} |      method's value is either a nested tree or a single value which is wrapped in array
  #          {:id => primary_key_id_value} |   if its the id method we leave the array off because we know it must be an int
  #          {integer => tree}                 for collections, each item retrieved will be represented by its id
  #
  # example
  # {
  #   "User" => {
  #     ["find", 12] => {
  #       :id => 12
  #       "email" => ["mitch@catprint.com"]
  #       "todos" => {
  #         "active" => {
  #           123 =>
  #             {
  #               id: 123,
  #               title: ["get fetch_records_from_db done"]
  #             },
  #           119 =>
  #             {
  #               id: 119
  #               title: ["go for a swim"]
  #             }
  #            ]
  #          }
  #        }
  #       }
  #     }
  #   }
  # }

  # To build this tree we first fill values for each individual vector, saving all the intermediate data
  # when all these are built we build the above hash structure

  # basic
  # [Todo, [find, 123], title]
  # -> [[Todo, [find, 123], title], "get fetch_records_from_db done", 123]

  # [User, [find_by_email, "mitch@catprint.com"], first_name]
  # -> [[User, [find_by_email, "mitch@catprint.com"], first_name], "Mitch", 12]

  # misses
  # [User, [find_by_email, "foobar@catprint.com"], first_name]
  #   nothing is found so nothing is downloaded
  # prerendering may do this
  # [User, [find_by_email, "foobar@catprint.com"]]
  #   which will return a cache object whose id is nil, and value is nil

  # scoped collection
  # [User, [find, 12], todos, active, *, title]
  # -> [[User, [find, 12], todos, active, *, title], "get fetch_records_from_db done", 12, 123]
  # -> [[User, [find, 12], todos, active, *, title], "go for a swim", 12, 119]

  # collection with nested belongs_to
  # [User, [find, 12], todos, *, team]
  # -> [[User, [find, 12], todos, *, team, name], "developers", 12, 123, 252]
  #    [[User, [find, 12], todos, *, team, name], nil, 12, 119]  <- no team defined for todo<119> so list ends early

  # collections that are empty will deliver nothing
  # [User, [find, 13], todos, *, team, name]   # no todos for user 13
  #   evaluation will get this far: [[User, [find, 13], todos], nil, 13]
  #   nothing will match [User, [find, 13], todos, team, name] so nothing will be downloaded


  # aggregate
  # [User, [find, 12], address, zip_code]
  # -> [[User, [find, 12], address, zip_code]], "14622", 12] <- note parent id is returned

  # aggregate with a belongs_to
  # [User, [find, 12], address, country, country_code]
  # -> [[User, [find, 12], address, country, country_code], "US", 12, 342]

  # collection * (for iterators etc)
  # [User, [find, 12], todos, overdue, *all]
  # -> [[User, [find, 12], todos, active, *all], [119, 123], 12]

  # [Todo, [find, 119], owner, todos, active, *all]
  # -> [[Todo, [find, 119], owner, todos, active, *all], [119, 123], 119, 12]


    class ServerDataCache

      # SECURITY - SAFE
      def initialize(acting_user, preloaded_records)
        @acting_user = acting_user
        @cache = []
        @requested_cache_items = []
        @preloaded_records = preloaded_records
      end

      if RUBY_ENGINE != 'opal'

        def get_model(str)
          # TODO move this hyper-operation and replace existing get_ar_model so it doesn't use AR::Base
          unless Hyperloop::InternalClassPolicy.regulated_classes.include? str
            Hyperloop::InternalPolicy.raise_operation_access_violation
          end
          str.constantize
        end

        # SECURITY - NOW SAFE
        def [](*vector)
          root = CacheItem.new(@cache, @acting_user, vector[0], @preloaded_records)
          vector[1..-1].inject(root) { |cache_item, method| cache_item.apply_method method if cache_item }
          vector[0] = get_model(vector[0])
          last_value = nil
          @cache.each do |cache_item|
            next if cache_item.root != root || @requested_cache_items.include?(cache_item)
            @requested_cache_items << cache_item
            last_value = cache_item
          end
          last_value
        end

        # SECURITY - SAFE
        def self.[](models, associations, vectors, acting_user)
          ActiveRecord::Base.public_columns_hash
          result = nil
          ActiveRecord::Base.transaction do
            cache = new(acting_user, ReactiveRecord::Base.save_records(models, associations, acting_user, false, false))
            vectors.each { |vector| cache[*vector] }
            result = cache.as_json
            raise ActiveRecord::Rollback, "This Rollback is intentional!"
          end
          result
        end

        # SECURITY - SAFE
        def clear_requests
          @requested_cache_items = []
        end

        # SECURITY - SAFE
        def as_json
          @requested_cache_items.inject({}) do |hash, cache_item|
            hash.deep_merge! cache_item.as_hash
          end
        end

        # SECURITY - SAFE
        def select(&block); @cache.select(&block); end

        # SECURITY - SAFE
        def detect(&block); @cache.detect(&block); end

        # SECURITY - SAFE
        def inject(initial, &block); @cache.inject(initial) &block; end

        class CacheItem

          attr_reader :vector
          attr_reader :absolute_vector
          attr_reader :root
          attr_reader :acting_user

          # SECURITY - SAFE
          def value
            @value # which is a ActiveRecord object
          end

          # SECURITY - SAFE
          def method
            @vector.last
          end

          # SECURITY - NOW SAFE
          def self.new(db_cache, acting_user, klass, preloaded_records)
            klass_constant = get_model(klass)
            if existing = db_cache.detect { |cached_item| cached_item.vector == [klass_constant] }
              return existing
            end
            super
          end

          # SECURITY - NOW SAFE
          def initialize(db_cache, acting_user, klass, preloaded_records)
            klass = get_model(klass)
            @db_cache = db_cache
            @acting_user = acting_user
            @vector = @absolute_vector = [klass]
            @value = klass
            @parent = nil
            @root = self
            @preloaded_records = preloaded_records
            db_cache << self
          end

          # SECURITY - UNSAFE
          def apply_method_to_cache(method)
            @db_cache.inject(nil) do |representative, cache_item|
              if cache_item.vector == vector
                if method == "*"
                  @value.check_permission_with_acting_user(@acting_user, :view_permitted?, :id)
                  cache_item.apply_star || representative
                elsif method == "*all"
                  @value.check_permission_with_acting_user(@acting_user, :view_permitted?, :id)
                  cache_item.build_new_cache_item(cache_item.value.collect { |record| record.id }, method, method)
                elsif method == "*count"
                  @value.check_permission_with_acting_user(@acting_user, :view_permitted?, :id)
                  cache_item.build_new_cache_item(cache_item.value.count, method, method)
                elsif preloaded_value = @preloaded_records[cache_item.absolute_vector + [method]]
                  cache_item.build_new_cache_item(preloaded_value, method, method)
                elsif aggregation = cache_item.aggregation?(method)
                  cache_item.build_new_cache_item(aggregation.mapping.collect { |attribute, accessor| cache_item.value[attribute] }, method, method)
                elsif !cache_item.value || cache_item.value.class == Array
                  representative
                else
                  @value.check_permission_with_acting_user(@acting_user, :send_permitted?, method)
                  begin
                    cache_item.build_new_cache_item(cache_item.value.send(*method), method, method)
                  rescue Exception => e
                    # ReactiveRecord::Pry::rescued(e)
                    ::Rails.logger.debug "\033[0;31;1mERROR: HyperModel exception caught when applying #{method} to db object #{cache_item.value}: #{e}\033[0;30;21m"
                    raise e, "HyperModel fetching records failed, exception caught when applying #{method} to db object #{cache_item.value}: #{e}", e.backtrace
                  end
                end
              else
                representative
              end
            end
          end

          # SECURITY - SAFE
          def aggregation?(method)
            if method.is_a?(String) && @value.class.respond_to?(:reflect_on_aggregation)
              aggregation = @value.class.reflect_on_aggregation(method.to_sym)
              if aggregation && !(aggregation.klass < ActiveRecord::Base) && @value.send(method)
                aggregation
              end
            end
          end

          # SECURITY - SAFE  NOTE FOR consistency permission is checked in apply_method_to_cache
          def apply_star
            if @value && @value.length > 0
              i = -1
              @value.inject(nil) do |representative, current_value|
                i += 1
                if preloaded_value = @preloaded_records[@absolute_vector + ["*#{i}"]]
                  build_new_cache_item(preloaded_value, "*", "*#{i}")
                else
                  build_new_cache_item(current_value, "*", "*#{i}")
                end
              end
            else
              build_new_cache_item([], "*", "*")
            end
          end

          # SECURITY - SAFE
          # TODO replace instance_eval with a method like clone_new_child(....)
          def build_new_cache_item(new_value, method, absolute_method)
            new_parent = self
            self.clone.instance_eval do
              @vector = @vector + [method]  # don't push it on since you need a new vector!
              @absolute_vector = @absolute_vector + [absolute_method]
              @value = new_value
              @db_cache << self
              @parent = new_parent
              @root = new_parent.root
              self
            end
          end

          # SECURITY - SAFE
          def apply_method(method)
            if method.is_a? Array and method.first == "find_by_id"
              method[0] = "find"
            elsif method.is_a? String and method =~ /^\*[0-9]+$/
              method = "*"
            end
            new_vector = vector + [method]
            @db_cache.detect { |cached_item| cached_item.vector == new_vector} || apply_method_to_cache(method)
          end

          # SECURITY - SAFE
          def jsonize(method)
            # sadly standard json converts {[:foo, nil] => 123} to {"['foo', nil]": 123}
            # luckily [:foo, nil] does convert correctly
            # so we check the methods and force proper conversion
            method.is_a?(Array) ? method.to_json : method
          end

          def as_hash(children = nil)
            unless children
              return {} if @value.is_a?(Class) and (@value < ActiveRecord::Base)
              children = [@value.is_a?(BigDecimal) ? @value.to_f : @value]
            end
            if @parent
              if method == "*"
                if @value.is_a? Array  # this happens when a scope is empty there is test case, but
                  @parent.as_hash({})      # does it work for all edge cases?
                else
                  @parent.as_hash({@value.id => children})
                end
              elsif @value.class < ActiveRecord::Base and children.is_a? Hash
                @parent.as_hash({jsonize(method) => children.merge({
                  :id => (method.is_a?(Array) && method.first == "new") ? [nil] : [@value.id],
                  @value.class.inheritance_column => [@value[@value.class.inheritance_column]],
                  })})
              elsif method == "*all"
                @parent.as_hash({jsonize(method) => children.first})
              else
                @parent.as_hash({jsonize(method) => children})
              end
            else
              {method.name => children}
            end
          end

          def to_json
            @value.to_json
          end

        end

      end

=begin
tree is a hash, target is the object that will be filled in with the data hanging off the key.
first time around target == nil, so for each key, value pair we do this: load_from_json(value, Object.const_get(JSON.parse(key)))
keys:
  ':*all':   target.replace tree["*all"].collect { |id| target.proxy_association.klass.find(id) }
  Example: {'*all': [1, 7, 19, 23]}  target is a collection and will now have 4 records: 1, 7, 19, 23

  'id':  if value is an array then target.id = value.first
  Example: {'id': [17]} Example the target is a record, and its id is now set to 17

  '*count': target.set_count_state(value.first)  note: set_count_state sets the count of a collection and updates the associated state variable
  integer-like-string-or-number: target.push_and_update_belongs_to(key)  note: collection will be a has_many association, so we are doing a target << find(key), and updating both ends of the relationship
  [:new, nnn] do a ReactiveRecord::Base.find_by_object_id(target.base_class, method[1]) and that becomes the new target, with val being passed allow_change
  [...] and current target is NOT an ActiveRecord Model (??? a collection ???) then send key to target, and that becomes new target
      but note if value is an array then the scope returned nil, so we destroy the bogus record, and set new target back to nil
        new_target.destroy and new_target = nil if value.is_a? Array
  [...] and current target IS AN ActiveRecord Model (not a collection) then target.backing_record.update_attribute([method], target.backing_record.convert(method, value.first))
  aggregation:
    target.class.respond_to?(:reflect_on_aggregation) and aggregation = target.class.reflect_on_aggregation(method) and !(aggregation.klass < ActiveRecord::Base)
      target.send "#{method}=", aggregation.deserialize(value.first)
  other-string-method-name:
    if value is a an array then value.first is the new value and we do target.send "{key}=", value.first
    if value is a hash
=end

      if RUBY_ENGINE == 'opal'
        def self.load_from_json(tree, target = nil)
          ignore_all = nil

          # have to process *all before any other items
          # we leave the "*all" key in just for debugging purposes, and then skip it below

          if sorted_collection = tree["*all"]
            target.replace sorted_collection.collect { |id| target.proxy_association.klass.find(id) }
          end

          if id_value = tree["id"] and id_value.is_a? Array
            target.id = id_value.first
          end
          tree.each do |method, value|
            method = JSON.parse(method) rescue method
            new_target = nil
            if method == "*all"
              next # its already been processed above
            elsif !target
              load_from_json(value, Object.const_get(method))
            elsif method == "*count"
              target.set_count_state(value.first)
            elsif method.is_a? Integer or method =~ /^[0-9]+$/
              new_target = target.push_and_update_belongs_to(method)
              #target << (new_target = target.proxy_association.klass.find(method))
            elsif method.is_a? Array
              if method[0] == "new"
                new_target = ReactiveRecord::Base.find_by_object_id(target.base_class, method[1])
              elsif !(target.class < ActiveRecord::Base)
                new_target = target.send(*method)
                # value is an array if scope returns nil, so we destroy the bogus record
                new_target.destroy and new_target = nil if value.is_a? Array
              else
                target.backing_record.update_attribute([method], target.backing_record.convert(method, value.first))
              end
            elsif target.class.respond_to?(:reflect_on_aggregation) and aggregation = target.class.reflect_on_aggregation(method) and
            !(aggregation.klass < ActiveRecord::Base)
              target.send "#{method}=", aggregation.deserialize(value.first)
            elsif value.is_a? Array
              target.send "#{method}=", value.first unless method == "id" # we handle ids first so things sync nicely
            elsif value.is_a? Hash and value[:id] and value[:id].first and association = target.class.reflect_on_association(method)
              # not sure if its necessary to check the id above... is it possible to for the method to be an association but not have an id?
              new_target = association.klass.find(value[:id].first)
              target.send "#{method}=", new_target
            elsif !(target.class < ActiveRecord::Base)
              new_target = target.send(*method)
              # value is an array if scope returns nil, so we destroy the bogus record
              new_target.destroy and new_target = nil if value.is_a? Array
            else
              new_target = target.send("#{method}=", target.send(method))
            end
            load_from_json(value, new_target) if new_target
          end
        end
      end
    end
  end
