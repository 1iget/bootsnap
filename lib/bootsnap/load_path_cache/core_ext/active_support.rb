module Bootsnap
  module LoadPathCache
    module CoreExt
      module ActiveSupport
        def self.with_bootsnap_fallback(error)
          yield
        rescue error
          without_bootsnap_cache { yield }
        end

        def self.without_bootsnap_cache
          prev = Thread.current[:without_bootsnap_cache] || false
          Thread.current[:without_bootsnap_cache] = true
          yield
        ensure
          Thread.current[:without_bootsnap_cache] = prev
        end

        module ClassMethods
          def autoload_paths=(o)
            r = super
            Bootsnap::LoadPathCache.autoload_paths_cache.reinitialize(o)
            r
          end

          def search_for_file(path)
            return super if Thread.current[:without_bootsnap_cache]
            begin
              Bootsnap::LoadPathCache.autoload_paths_cache.find(path)
            rescue Bootsnap::LoadPathCache::ReturnFalse
              nil # doesn't really apply here
            end
          end

          def autoloadable_module?(path_suffix)
            Bootsnap::LoadPathCache.autoload_paths_cache.has_dir?(path_suffix)
          end

          def remove_constant(const)
            CoreExt::ActiveSupport.without_bootsnap_cache { super }
          end

          # If we can't find a constant using the patched implementation of
          # search_for_file, try again with the default implementation.
          #
          # These methods call search_for_file, and we want to modify its
          # behaviour.  The gymnastics here are a bit awkward, but it prevents
          # 200+ lines of monkeypatches.
          def load_missing_constant(from_mod, const_name)
            CoreExt::ActiveSupport.with_bootsnap_fallback(NameError) { super }
          end

          if ::ActiveSupport::VERSION::MAJOR > 3
            def depend_on(file_name, message = "No such file to load -- %s.rb")
              CoreExt::ActiveSupport.with_bootsnap_fallback(LoadError) { super }
            end
          else
            def depend_on(file_name, swallow_load_errors = false, message = "No such file to load -- %s.rb")
              CoreExt::ActiveSupport.with_bootsnap_fallback(LoadError) { super }
            end
          end
        end
      end
    end
  end
end

module ActiveSupport
  module Dependencies
    class << self
      prepend Bootsnap::LoadPathCache::CoreExt::ActiveSupport::ClassMethods
    end
  end
end
