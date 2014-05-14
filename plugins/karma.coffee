karma = require "karma"
globStream = require "glob-stream"
webappSpell = require "warlock-spell-webapp"
File = require "vinyl"

module.exports = ( warlock ) ->
  warlock.flow 'karma-get-vendor',
    source: [
      '<%= globs.vendor.test %>'
      '<%= globs.source.test %>'
    ]
    source_options:
      read: false
    merge: "flow::karma-single-run::20" # FIXME: the merge MUST be sequential
    depends: [ 'flow::scripts-to-build' ]

  warlock.flow 'karma-single-run',
    source: [ '<%= paths.build_js %>/**/*.js' ]
    source_options:
      read: false
    depends: [ 'flow::scripts-to-build' ]
    tasks: [ 'webapp-build' ]

  .add( 10, 'karma-sort-vendor', webappSpell.sortFilesByVendor( warlock, "globs.vendor.js" ), { raw: true } )
  .add( 50, 'karma.single-run', ( options, stream ) ->
    stream.map ( files ) ->
      options.files = files
        .filter( ( file ) -> file and file?.path )
        .map( ( file ) -> file.path )

      startKarmaServer options
  , { raw: true, collect: true } )
  .add( 51, 'karma.reporter', ( options ) ->
    warlock.streams.map ( code ) ->
      warlock.verbose.log "Karma exited with code #{code}."
      code
  )

  startKarmaServer = warlock.streams.highland.wrapCallback ( options, callback ) ->
    run = ( opts ) ->
      warlock.log.log "Starting Karma Server."
      karma.server.start opts, ( code ) ->
        callback null, code

    # To ensure the config file *overwrites* any default configuration settings, we load it
    # manually.
    if options?.configFile?
      warlock.verbose.log "[EXPERIMENTAL] Merging Karma config file #{options.configFile}"

      # Fake Karma config object
      # FIXME(jdm): This is dirty.
      config =
        set: ( optionsFromFile ) ->
          options = warlock.util.merge options, optionsFromFile

      try
        configFn = require warlock.file.absolutePath( options.configFile )
        warlock.fatal "Karma config file must export a function." if not warlock.util.isFunction configFn
        configFn config
        delete options.configFile
      catch e
        warlock.fatal e

    run options

