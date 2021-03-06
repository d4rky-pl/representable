require 'representable/binding'
require 'representable/bindings/hash_bindings.rb'

module Representable
  module XML
    class PropertyBinding < Binding
      include Binding::Object

      def self.build_for(definition, *args)
        return CollectionBinding.new(definition, *args)      if definition.array?
        return HashBinding.new(definition, *args)            if definition.hash? and not definition[:use_attributes] # FIXME: hate this.
        return AttributeHashBinding.new(definition, *args)   if definition.hash? and definition[:use_attributes]
        return AttributeBinding.new(definition, *args)       if definition[:attribute]
        return ContentBinding.new(definition, *args)         if definition[:content]
        new(definition, *args)
      end

      def write(parent, value)
        wrap_node = parent

        if wrap = self[:wrap]
          parent << wrap_node = node_for(parent, wrap)
        end

        wrap_node << serialize_for(value, parent)
      end

      def read(node)
        nodes = find_nodes(node)
        return FragmentNotFound if nodes.size == 0 # TODO: write dedicated test!

        deserialize_from(nodes)
      end

      # Creates wrapped node for the property.
      def serialize_for(value, parent)
        node = node_for(parent, as)
        serialize_node(node, value)
      end

      def serialize_node(node, value)
        return serialize(value) if typed?

        node.content = serialize(value)
        node
      end

      def deserialize_from(nodes)
        content_for deserialize(nodes.first)
        #deserialize(nodes.first)
      end

      # DISCUSS: why is this public?
      def serialize_method
        :to_node
      end

      def deserialize_method
        :from_node
      end

    private
      def xpath
        as
      end

      def find_nodes(doc)
        selector  = xpath
        selector  = "#{self[:wrap]}/#{xpath}" if self[:wrap]
        nodes     = doc.xpath(selector)
      end

      def node_for(parent, name)
        Nokogiri::XML::Node.new(name.to_s, parent.document)
      end

      def content_for(node) # TODO: move this into a ScalarDecorator.
        return node if typed?

        node.content
      end
    end

    class CollectionBinding < PropertyBinding
      def serialize_for(value, parent)
        # return NodeSet so << works.
        set_for(parent, value.collect { |item| super(item, parent) })
      end

      def deserialize_from(nodes)
        content_nodes = nodes.collect do |item| # TODO: move this to Node?
          content_for(item)
        end

        # *Deserializer doesn't want anything format specific!
        CollectionDeserializer.new(self).deserialize(content_nodes)
      end

    private
      def set_for(parent, nodes)
        Nokogiri::XML::NodeSet.new(parent.document, nodes)
      end
    end


    class HashBinding < CollectionBinding
      def serialize_for(value, parent)
        set_for(parent, value.collect do |k, v|
          node = node_for(parent, k)
          serialize_node(node, v)
        end)
      end

      def deserialize_from(nodes)
        {}.tap do |hash|
          nodes.children.each do |node|
            hash[node.name] = deserialize(content_for node)
          end
        end
      end
    end

    class AttributeHashBinding < CollectionBinding
      # DISCUSS: use AttributeBinding here?
      def write(parent, value)  # DISCUSS: is it correct overriding #write here?
        value.collect do |k, v|
          parent[k] = serialize(v.to_s)
        end
        parent
      end

      def deserialize_from(node)
        {}.tap do |hash|
          node.each do |k,v|
            hash[k] = deserialize(v)
          end
        end
      end
    end


    # Represents a tag attribute. Currently this only works on the top-level tag.
    class AttributeBinding < PropertyBinding
      def read(node)
        deserialize(node[as])
      end

      def serialize_for(value, parent)
        parent[as] = serialize(value.to_s)
      end

      def write(parent, value)
        serialize_for(value, parent)
      end
    end

    # Represents tag content.
    class ContentBinding < PropertyBinding
      def read(node)
        node.content
      end

      def serialize_for(value, parent)
        parent.content = serialize(value.to_s)
      end

      def write(parent, value)
        serialize_for(value, parent)
      end
    end
  end
end
