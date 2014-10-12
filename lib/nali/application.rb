module Nali

  class Application < Sinatra::Base
   
    set :root,          File.expand_path( '.' )
    set :database_file, File.join( root, 'config/database.yml' )
    set :assets,        Sprockets::Environment.new( root )
    set :assets_digest, false
    set :assets_debug,  false
    set :static,        true
    
    register Sinatra::ActiveRecordExtension
    
    configure :development do
      register Sinatra::Reloader
      also_reload File.join( root, '**/*.rb' )
    end
    
    require File.join( root, 'config/environments', environment.to_s )
    
    configure do
      
      assets.cache = Sprockets::Cache::FileStore.new File.join( root, 'tmp/cache' )
      
      assets.append_path File.join( Nali.path, 'assets/javascripts' ) 
      
      %w( app/templates app/assets/stylesheets app/assets/javascripts lib/assets/stylesheets 
          lib/assets/javascripts vendor/assets/stylesheets vendor/assets/javascripts
      ).each { |path| assets.append_path File.join( root, path ) }

      Sprockets::Helpers.configure do |config|
        config.environment = assets
        config.debug       = assets_debug
        config.digest      = assets_digest
      end
      
    end

    get '/assets/*.*' do |path, ext|
      pass if ext == 'html' or not asset = settings.assets[ path + '.' + ext ]
      content_type asset.content_type
      params[ :body ] ? asset.body : asset
    end

    get '/*' do
      if !request.websocket?
        settings.assets[ 'application.html' ]
      else
        request.websocket do |client|
          client.onopen    { Nali::Clients.on_client_connected client }
          client.onmessage { |message| Nali::Clients.on_received_message( client, JSON.parse( message ).keys_to_sym! ) }
          client.onclose   { Nali::Clients.on_client_disconnected client }
        end
      end
    end
    
    def self.access_options
      if settings.environment == :development
        YAML.load_file( File.join( root, 'app/models/access.yml' ) ).keys_to_sym!
      else
        @access_options ||= YAML.load_file( File.join( root, 'app/models/access.yml' ) ).keys_to_sym!
      end
    end
    
    def self.initialize!
      Dir[ File.join( root, 'lib/*/**/*.rb' ) ].each { |file| require( file ) }
      Dir[ File.join( root, 'app/**/*.rb'   ) ].each { |file| require( file ) }
      require File.join( root, 'config/application' )
      self
    end
    
    def self.tasks
      initialize!
      require 'sinatra/activerecord/rake'
      require 'rake/sprocketstask'
      Rake::SprocketsTask.new do |task|
        task.environment = settings.assets
        task.output      = File.join( public_folder, 'assets' )
        task.assets      = %w( application.html application.js application.css )
      end
    end
      
  end  

end