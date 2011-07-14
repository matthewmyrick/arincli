# Copyright (C) 2011 American Registry for Internet Numbers

require 'optparse'
require 'rexml/document'
require 'base_opts'
require 'config'
require 'constants'
require 'reg_rws'
require 'poc_reg'
require 'editor'

module ARINr

  module Registration

    class PocMain < ARINr::BaseOpts

      ARINP_LOG_SUFFIX = 'arinp'
      ARINP_CREATE_POC_FILE = 'arinp_create_poc'
      ARINP_MODIFY_POC_FILE = 'arinp_modify_poc'

      def initialize args, config = nil

        if config
          @config = config
        else
          @config = ARINr::Config.new( ARINr::Config::formulate_app_data_dir() )
        end

        @opts = OptionParser.new do |opts|

          opts.banner = "Usage: arinp [options] [POC_HANDLE]"

          opts.separator ""
          opts.separator "Actions:"

          opts.on( "--create",
                   "Creates a Point of Contact." ) do |create|
            if @config.options.modify_poc || @config.options.delete_poc || @config.options.make_template
              raise OptionParser::InvalidArgument, "Can't create and modify, delete, or template at the same time."
            end
            @config.options.create_poc = true
          end

          opts.on( "--modify",
                   "Modifies a Point of Contact." ) do |modify|
            if @config.options.create_poc || @config.options.delete_poc || @config.options.make_template
              raise OptionParser::InvalidArgument, "Can't create and modify, delete, or template at the same time."
            end
            @config.options.modify_poc = true
          end

          opts.on( "--delete",
                   "Deletes a Point of Contact." ) do |delete|
            if @config.options.create_poc || @config.options.modify_poc || @config.options.make_template
              raise OptionParser::InvalidArgument, "Can't create and modify, delete, or template at the same time."
            end
            @config.options.delete_poc = true
          end

          opts.on( "--yaml FILE",
                   "Create a YAML template for a Point of Contact." ) do |yaml|
            if @config.options.create_poc || @config.options.modify_poc || @config.options.delete_poc
              raise OptionParser::InvalidArgument, "Can't create and modify, delete or template at the same time."
            end
            @config.options.make_template = true
            @config.options.template_type = "YAML"
            @config.options.template_file = yaml
          end

          opts.separator ""
          opts.separator "Communications Options:"

          opts.on( "-U", "--url URL",
                   "The base URL of the Registration RESTful Web Service." ) do |url|
            @config.config[ "registration" ][ "url" ] = url
          end

          opts.on( "-A", "--apikey APIKEY",
                   "The API KEY to use with the RESTful Web Service." ) do |apikey|
            @config.config[ "registration" ][ "apikey" ] = apikey.to_s.upcase
          end

          opts.separator ""
          opts.separator "File Options:"

          opts.on( "-f", "--file FILE",
                   "The template to be read for the action taken." ) do |file|
            @config.options.data_file = file
            @config.options.data_file_specified = true
          end
        end

        add_base_opts( @opts, @config )

        begin
          @opts.parse!( args )
          if !@config.options.help && args != nil && args != []
            if ( ! @config.options.delete_poc ) && ( ! @config.options.create_poc ) && ( ! @config.options.make_template )
              @config.options.modify_poc = true
            end
            if ! args[ 0 ] && @config.options.delete_poc
              raise OptionParser::InvalidArgument, "You must specify a POC Handle to delete a POC."
            end
            if ! args[ 0 ] && @config.options.modify_poc
              raise OptionParser::InvalidArgument, "You must specify a POC Handle to modify a POC."
            end
            if ! args[ 0 ] && @config.options.make_template
              raise OptionParser::InvalidArgument, "You must specify a POC Handle to template."
            end
            if ! args[ 0 ] =~ ARINr::POC_HANDLE_REGEX
              raise OptionParser::InvalidArgument, args[ 0 ] + " does not look like a POC Handle."
            end
          end
        rescue OptionParser::InvalidArgument => e
          puts e.message
          puts "use -h for help"
          exit
        end
        @config.options.argv = args

      end

      def modify_poc
        if !@config.options.data_file
          @config.options.data_file = @config.make_file_name( ARINP_MODIFY_POC_FILE )
          data_to_send = make_yaml_template(@config.options.data_file, @config.options.argv[0])
          if data_to_send
            editor = ARINr::Editor.new(@config)
            edited = editor.edit(@config.options.data_file)
            if ! edited
              @config.logger.mesg( "No changes were made to POC data file. Aborting." )
              return
            end
          end
        else
          data_to_send = true
        end
        if data_to_send
          reg = ARINr::Registration::RegistrationService.new(@config, ARINP_LOG_SUFFIX)
          file = File.new(@config.options.data_file, "r")
          data = file.read
          file.close
          poc = ARINr::Registration.yaml_to_poc(data)
          poc_element = ARINr::Registration.poc_to_element(poc)
          return_data = ARINr::pretty_print_xml_to_s(poc_element)
          if reg.modify_poc(poc.handle, return_data)
            @config.logger.mesg(@config.options.argv[0] + " has been modified.")
          else
            if !@config.options.data_file_specified
              @config.logger.mesg( 'Use "arinp" to re-edit and resubmit.' )
            else
              @config.logger.mesg( 'Edit file then use "arinp -f ' + @config.options.data_file + ' --modify" to resubmit.')
            end
          end
        else
          @config.logger.mesg( "No modification source specified." )
        end
      end

      def run

        if( @config.options.help )
          help()
        elsif( @config.options.argv == nil || @config.options.argv == [] )
          if File.exists?( @config.make_file_name( ARINP_MODIFY_POC_FILE ) )
            @config.options.modify_poc = true
            @config.options.data_file = @config.make_file_name( ARINP_MODIFY_POC_FILE )
          elsif File.exists?( @config.make_file_name( ARINP_CREATE_POC_FILE ) ) && !@config.options.create_poc
            @config.options.create_poc = true
            @config.options.data_file = @config.make_file_name( ARINP_CREATE_POC_FILE )
          elsif ! @config.options.create_poc
              help()
          end
        end

        @config.logger.mesg( ARINr::VERSION )
        @config.setup_workspace

        if @config.options.make_template
          make_yaml_template( @config.options.template_file, @config.options.argv[ 0 ] )
        elsif @config.options.modify_poc
          modify_poc()
        elsif @config.options.delete_poc
          reg = ARINr::Registration::RegistrationService.new( @config )
          element = reg.delete_poc( @config.options.argv[ 0 ] )
          @config.logger.mesg( @config.options.argv[ 0 ] + " deleted." ) if element
        elsif @config.options.create_poc
          create_poc()
        else
          @config.logger.mesg( "Action or feature is not implemented." )
        end

      end

      def help

        puts ARINr::VERSION
        puts ARINr::COPYRIGHT
        puts <<HELP_SUMMARY

This program uses ARIN's Reg-RWS RESTful API to query ARIN's Registration database.
The general usage is "arinp POC_HANDLE" where POC_HANDLE is the identifier of the point
of contact to modify. Other actions can be specified with options, but if not explicit
action is given then modification is assumed.

HELP_SUMMARY
        puts @opts.help
        exit

      end

      def make_yaml_template file_name, poc_handle
        success = false
        reg = ARINr::Registration::RegistrationService.new @config, ARINP_LOG_SUFFIX
        element = reg.get_poc( poc_handle )
        if element
          poc = ARINr::Registration.element_to_poc( element )
          file = File.new( file_name, "w" )
          file.puts( ARINr::Registration.poc_to_template( poc ) )
          file.close
          success = true
          @config.logger.trace( poc_handle + " saved to " + file_name )
        end
        return success
      end

      def create_poc
        if ! @config.options.data_file
          poc = ARINr::Registration::Poc.new
          poc.first_name="PUT FIRST NAME HERE"
          poc.middle_name="PUT MIDDLE NAME HERE"
          poc.last_name="PUT LAST NAME HERE"
          poc.company_name="PUT COMPANY NAME HERE"
          poc.type="PERSON"
          poc.street_address=["FIRST STREET ADDRESS LINE HERE", "SECOND STREET ADDRESS LINE HERE"]
          poc.city="PUT CITY HERE"
          poc.state="PUT STATE, PROVINCE, OR REGION HERE"
          poc.country="PUT COUNTRY HERE"
          poc.postal_code="PUT POSTAL OR ZIP CODE HERE"
          poc.emails=["YOUR_EMAIL_ADDRESS_HERE@SOME_COMPANY.NET"]
          poc.phones={ "office" => ["1-XXX-XXX-XXXX", "x123"]}
          poc.comments=["PUT FIRST LINE OF COMMENTS HEERE", "PUT SECOND LINE OF COMMENTS HERE"]
          @config.options.data_file = @config.make_file_name( ARINP_CREATE_POC_FILE )
          file = File.new( @config.options.data_file, "w" )
          file.puts( ARINr::Registration.poc_to_template( poc ) )
          file.close
        end
        if ! @config.options.data_file_specified
          editor = ARINr::Editor.new( @config )
          edited = editor.edit( @config.options.data_file )
          if ! edited
            @config.logger.mesg( "No modifications made to POC data file. Aborting." )
            return
          end
        end
        reg = ARINr::Registration::RegistrationService.new(@config,ARINP_LOG_SUFFIX)
        file = File.new(@config.options.data_file, "r")
        data = file.read
        file.close
        poc = ARINr::Registration.yaml_to_poc( data )
        poc_element = ARINr::Registration.poc_to_element(poc)
        send_data = ARINr::pretty_print_xml_to_s(poc_element)
        element = reg.create_poc( send_data )
        if element
          new_poc = ARINr::Registration.element_to_poc( element )
          @config.logger.mesg( "New point of contact created with handle " + new_poc.handle )
          @config.logger.mesg( 'Use "arinp ' + new_poc.handle + '" to modify this point of contact.')
        else
          @config.logger.mesg( "Point of contact was not created." )
          if !@config.options.data_file_specified
            df = @config.make_file_name( ARINP_MODIFY_POC_FILE )
            File.delete( df ) if File.exists?( df )
            @config.logger.mesg( 'Use "arinp" to re-edit and resubmit.' )
          else
            @config.logger.mesg( 'Edit file then use "arinp -f ' + @config.options.data_file + ' --create" to resubmit.')
          end
        end
      end

    end

  end

end
