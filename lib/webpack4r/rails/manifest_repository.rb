# frozen_string_literal: true

module Webpack4r
  module Rails
    class ManifestRepository
      class NotFoundError < StandardError; end

      attr_accessor :default

      def initialize
        @manifests = {}
        @default = nil # a pointer to a default manifest
      end

      def all_manifests
        @manifests.values
      end

      # @private
      def add(key, path, **options)
        manifest = Webpack4r::Manifest.new(path, options)
        # Mark a first one as a default
        @default = manifest if @manifests.empty?
        @manifests[key.to_sym] = manifest
      end

      def get(key)
        @manifests[key.to_sym] || raise(NotFoundError, "manifest associated with #{key} not found")
      end
    end
  end
end