module Coinbase
  module Exchange
    # Response item abstract model
    class APIObject < Hash
      def initialize(data)
        super
        update(data)
      end

      def update(data)
        return if data.nil?
        data.each { |key, val| self[key] = val } if data.is_a?(Hash)
      end

      def format(var)
        return if var.nil?
        # Looks like a number or currency
        if var =~ /^.{0,1}\s*[0-9,]*\.{0,1}[0-9]*$/
          BigDecimal(var.gsub(/[^0-9\.\-]/, ''))
        else
          var
        end
      end

      # This is common enough that we should override the hash method
      def size
        format(self['size']) || super
      end

      def method_missing(method, *args, &blk)
        format(self[method.to_s]) || super
      end

      def respond_to_missing?(method, include_all = false)
        self.key?(method.to_s) || super
      end
    end
  end
end
