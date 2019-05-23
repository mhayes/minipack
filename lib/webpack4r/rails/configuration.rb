# frozen_string_literal: true

module Webpack4r
  module Rails
    # 1-level or 2-levels configuration system. With the typical single site usecase,
    # only the root instance exists as a singleton. If you manage more then one site,
    # each configuration is stored at the 2nd level of the configuration tree.
    class Configuration
      class Collection
        include Enumerable
        class NotFoundError < StandardError; end

        def initialize(configs = [])
          @configs = configs.map(&:id).zip(configs).to_h
        end

        def find(id)
          @configs[id] || raise(NotFoundError, "collection not found by #{id}")
        end

        def each
          @configs.values.each { |c| yield c }
        end
      end

      class Error < StandardError; end

      ROOT_DEFAULT_ID = :''

      class << self
        def config_attr(prop)
          define_method(prop) do
            @config.fetch(prop, @parent&.public_send(prop))
          end

          define_method("#{prop}=".to_sym) do |v|
            @config[prop] = v
          end
        end
      end

      # Private
      config_attr :root_path
      config_attr :id

      config_attr :cache

      # The base directory of the frontend.
      config_attr :base_path

      config_attr :manifest

      # The lazy compilation is cached until a file is change under the tracked paths.
      config_attr :watched_paths

      # The command for bundling assets
      config_attr :build_command

      # The command for installation of npm packages
      config_attr :install_command

      # Initializes a new instance of Configuration class.
      #
      # @param [Configuration,nil] parent refenrece to the parent configuration instance.
      def initialize(parent = nil)
        @parent = parent
        # Only a root instance can have children, which are sub configurations each site.
        @children = {}
        @config = {}

        # If self is a configuration for a specific site, the getting attrs
        # not being configured are delegated to the root configuration, so
        # only root configuration object can have default values.
        reset_defaults! if root?
      end

      # Register a sub configuration with a site name, with a manifest file
      # optionally. You can configure per site.
      #
      # @param [Symbol] id uniq name of the site
      # @param [String] path path of the manifest file
      # @yieldparam [Configuration] config a sub configuration instance is sent to the block
      def add(id, path = nil)
        raise Error, 'Defining a sub configuration under a sub is not allowed' if leaf?

        id = id.to_sym
        config = self.class.new(self)
        config.id = id
        config.manifest = path unless path.nil?

        # Link the root to the child
        @children[id] = config

        # The sub configuration can be configured within a block
        yield config if block_given?

        config
      end

      def children
        Collection.new(@children.values)
      end

      # Return scoped leaf nodes in self and children. This method is useful
      # to get the concrete(enabled, or active) configuration instances.
      # Each leaf inherit parameters from parent, so leaves always become
      # active.
      def leaves
        col = @children.empty? ? [self] : @children.values
        Collection.new(col)
      end

      # TODO: This will be moved to Webpack4r::Rails.manifests in the future.
      def manifests
        raise Error, 'Calling #manifests is only allowed from a root' unless root?

        repo = ManifestRepository.new
        #  Determine if a single manifest mode or multiple manifests(multiple site) mode
        targets =  @children.empty? ? [self] : @children.values
        targets.each do |config|
          repo.add(config.id, config.manifest, cache: config.cache)
        end
        repo
      end

      # Resolve base_path as an absolute path
      #
      # @return [String]
      def resolved_base_path
        File.expand_path(base_path || '.', root_path)
      end

      # Resolve watched_paths as absolute paths
      #
      # @return [Array<String>]
      def resolved_watched_paths
        base = resolved_base_path
        watched_paths.map { |path| File.expand_path(path, base) }
      end

      # @return [String]
      def cache_path
        File.join(root_path, 'tmp', 'cache', 'webpack4r')
      end

      private

      def reset_defaults!
        @config = {
          id: ROOT_DEFAULT_ID,
          cache: false,
          watched_paths: [
            'package.json',
            'package-lock.json',
            'yarn.lock',
            'webpack.config.js',
            'webpackfile.js',
            'config/webpack.config.js',
            'config/webpackfile.js',
            'app/javascripts/**/*',
          ],
          build_command: 'node_modules/.bin/webpack',
          install_command: 'npm install',
        }
      end

      def root?
        @parent.nil?
      end

      def leaf?
        !root?
      end
    end
  end
 end