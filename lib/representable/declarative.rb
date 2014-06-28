module Representable
  module Declarative
    def representable_attrs
      @representable_attrs ||= build_config
    end

    def representation_wrap=(name)
      representable_attrs.wrap = name
    end

    def collection(name, options={}, &block)
      options[:collection] = true # FIXME: don't override original.
      property(name, options, &block)
    end

    def hash(name=nil, options={}, &block)
      return super() unless name  # allow Object.hash.

      options[:hash] = true
      property(name, options, &block)
    end

    # Allows you to nest a block of properties in a separate section while still mapping them to the outer object.
    def nested(name, options={}, &block)
      options = options.merge(
        :use_decorator => true,
        :getter        => lambda { |*| self },
        :setter        => lambda { |*| },
        :instance      => lambda { |*| self }
      ) # DISCUSS: should this be a macro just as :parse_strategy?

      property(name, options, &block)
    end

    def property(name, options={}, &block)
      base     = nil

      if options[:inherit] # TODO: move this to Definition.
        parent = representable_attrs[name]
        base = parent[:extend].evaluate(nil) if parent[:extend]# we can savely assume this is _not_ a lambda. # DISCUSS: leave that in #representer_module?
      end # FIXME: can we handle this in super/Definition.new ?

      if block_given?
        options[:extend] = inline_representer_for(base, representable_attrs.features, name, options, &block)
      end

      return parent.merge!(options) if options.delete(:inherit)

      # original ::property:
      representable_attrs << definition_class.new(name, options)
    end

    def inline_representer(*args, &block) # DISCUSS: separate module?
      build_inline(*args, &block)
    end

    def build_inline(base, features, name, options, &block) # DISCUSS: separate module?
      Module.new do
        include *features # Representable::JSON or similar.
        include base if base

        instance_exec &block
      end
    end

  private
    def inline_representer_for(base, features, name, options, &block)
      representer = options[:use_decorator] ? Decorator : self
      features    = [representer_engine] + features

      representer.inline_representer(base, features.reverse, name, options, &block)
    end

    def definition_class
      Definition
    end

    def build_config
      Config.new
    end
  end # Declarations
end