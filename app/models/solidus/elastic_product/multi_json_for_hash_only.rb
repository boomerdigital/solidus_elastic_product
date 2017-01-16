module Solidus::ElasticProduct

  # Customize the default MultiJson serializer to not do double
  # serialization when input is string. Reason is that we already
  # suppy a string as the `data` argument to the #bulk ruby api
  module MultiJsonForHashOnly
    extend ::MultiJson

    # Serialize a Hash to JSON string
    # Only do so when object is not already a string
    #
    def self.dump(object, options={})
      return object if object.kind_of? String
      super
    end
  end
end
