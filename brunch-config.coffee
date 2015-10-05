log4js = require 'umd-builder/log4js'
logger = log4js.getLogger 'brunch-config'
util = require('util')

hasOwn = Object::hasOwnProperty

# Quick glob to regexp
processSpecial = do ->
    sep = '[\\/\\\\]'
    nsep = '[^\\/\\\\]'
    nnsep = nsep + '*'
    star = '\\*'
    nstar = '\\*{2,}'
    specialPattern = new RegExp '(?:' + [
        # 1 # /**$ => /**: everything
        # 1 # ioio/**$ => /**: everything
        '(' + sep + nstar + '$)'

        # 2 # ouiuo/**/iuuo => /**/: sep, (everything, sep) or nothing
        '(' + sep + nstar + sep + ')'

        # 3 # ioio/**fodpo => /**: sep, everything
        '(' + sep + nstar + ')'

        # 4.1 # **/$ => **/: everything, sep
        # 4.2 # **/iofid => **/: everything, sep
        # 4.3 # fiodu**/iofid => **/: everything, sep
        '(' + nstar + sep + ')'
        
        # 5.1 # ** => **: everything
        # 5.2 # iido** => **: everything
        # 5.3 # **opoio => **: everything
        '(' + nstar + ')'

        # 6 # ouiuo/*/iuuo => /*/: sep, (nnsep, sep) or nothing
        '(' + sep + star + sep + ')'

        '(' + [
            # 7.1 # /* => /*$: nnsep
            # 7.2 # ioio/* => /*$: nnsep
            sep + star + '$'

            # 7.3 # */ => */$: nnsep
            star + sep + '$'

            # 7.4 # ioio/*fodpo => *: nnsep
            # 7.5 # fiodu*/iofid => *: nnsep
            # 7.6 # iido* => *: nnsep
            # 7.7 # *opoio => *: nnsep
            # 7.8 # */iofid => *: nnsep
            # 7.9 # * => *: nnsep
            star
        ].join('|') + ')'

        # 8 # http://www.regular-expressions.info/characters.html#special
        '([' + '\\/^$.|?*+()[]{}'.split('').join('\\') + '])'

    ].join('|') + ')', 'g'

    map =
        # keep special meaning
        '|': '|'
        '$': '$'

        # ignore OS specific path sep
        '/': sep
        '\\': sep

    (str)->
        str.replace specialPattern, (match)->
            if arguments[1] or arguments[5]
                # everything
                return '.*?'

            if arguments[2]
                # sep, (everything, sep) or nothing
                return sep + '(?:.*?' + sep + '|)'

            if arguments[3]
                # sep, everything
                return sep + '.*?'

            if arguments[4]
                # everything, sep
                return '.*?' + sep

            if arguments[6]
                # sep, (nnsep, sep) or nothing
                return sep + '(?:' + nnsep + sep + '|)'

            if arguments[7]
                # nnsep
                return nnsep

            map[match] or '\\' + match

getJoinConfig = (include, exclude) ->

    if Array.isArray include
        include = processSpecial include.join('|')
    else
        include = ''

    if Array.isArray exclude
        exclude = processSpecial exclude.join('|')
    else
        exclude = ''

    if include.length is 0 and exclude.length is 0
        /(?!^)^/ # never matches, similar to true === false
    else if exclude.length is 0
        new RegExp '^(?:' + include + ')'
    else if include.length is 0
        new RegExp '^(?!' + exclude + ')'
    else
        new RegExp '^(?!' + exclude + ')(?:' + include + ')'

# https://github.com/brunch/brunch/blob/stable/docs/config.md
exports.config =
    # workers: enabled: false
    getJoinConfig: getJoinConfig

    requirejs:
        # http://requirejs.org/docs/api.html#config-map
        map: '*': underscore: 'lodash'
        loader: 'umd-stdlib/core/depsLoader'

    # add some compilers
    # amd and copy are required for any project
    compilers: [
        require('umd-builder/lib/compilers/amd')
        require('umd-builder/lib/compilers/copy')
        require('umd-builder/lib/compilers/esprima')
        require('umd-builder/lib/compilers/handlebars')
        require('umd-builder/lib/compilers/jst/jst')
        require('umd-builder/lib/compilers/markdown')
        require('umd-builder/lib/compilers/relativecss')
        require('umd-builder/lib/compilers/stylus')
    ]

    # TODO : take from compilers
    # in brunch 1.8.x, compilers are not publicly available
    # used by builder to know what are the js files
    jsExtensions: /\.(?:js|hbs|handlebars|markdown|mdown|mkdn|md|mkd|mdwn|mdtxt|mdtext|text|coffee(?:\.md)?|litcoffee)$/

    modules:
        nameCleaner: (path, ext = false)->
            if not _isVendor path
                path = path.replace(/^(?:app[\/\\]node_modules|bower_components|components)[\/\\](.*)$/, '$1')

            path = path.replace(/[\\]/g, '/')
            if ext then path else path.replace(/\.[^.]*$/, '')

        amdDestination: (path, ext = false)->
            if not _isVendor path
                path = path.replace(/^(?:app[\/\\]node_modules|bower_components|components)[\/\\](.*)$/, 'node_modules/$1')

            path = path.replace(/[\\]/g, '/')
            if ext then path else path.replace(/\.[^.]*$/, '')

        isCustomUmdModule:  (path, data)->
            /(?:factory\s*=\s*function(?:\s+\w+)?|function\s+factory)\s*\(\s*require\s*/.test data

        wrapper: (path, data, isVendor) ->
            if isVendor
                logger.debug "Not wrapping '#{path}', is vendor file"
                data
            else
                modulePath = nameCleaner path

                if isCustomUmdModule path, data
                    logger.debug "Custom umd wrapping for '#{path}'"
                    """
                    require.define({"#{modulePath}": function(exports, ctxRequire, module) {
                        var deps;

                        #{data}

                        module.exports = depsLoader.common.call(this, ctxRequire, "common", deps, factory);
                    }});\n
                    """
                else
                    logger.debug "commonJs wrapping for '#{path}'"
                    """
                    require.define({"#{modulePath}": function(exports, require, module) {
                        #{data}
                    }});\n
                    """

    files:
        javascripts:
            joinTo:
                'javascripts/app.js': getJoinConfig ['app/node_modules/']
                'javascripts/vendor.js': getJoinConfig ['bower_components/', 'components/', 'vendor/'], ['vendor/require.js$', 'vendor/html5shiv.js$', 'vendor/respond.umd.js$']

        stylesheets:
            joinTo:
                'stylesheets/app.css': getJoinConfig ['app/node_modules/', 'bower_components/', 'components/', 'vendor/'], ['app/node_modules/**/variables.styl$']

        templates:
            joinTo: 'javascripts/app.js'
    
    plugins:
        coffeescript:
            bare: true
        jst:
            # _.template uses with when not variable is given. Since with is not recommended on MDN, I prefer not to use it
            # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/with
            variable: 'root'
            ignore: /<%--([\s\S]+?)--%>/g # added for comments within templates
            escape: /<%-([\s\S]+?)%>/g # default value
            interpolate: /<%=([\s\S]+?)%>/g # default value
            evaluate: /<%([\s\S]+?)%>/g # default value

    server:
        path: './server/HttpServer'
        host: '127.0.0.1'
        port: 3330

    paths:
        public: 'public'
        watched: [ 'app', 'vendor' ]

    conventions:
        ignored: [
            /[\\/]\./
            /[\\/]_/
            /bower.json/
            /component.json/
            /package.json/
            /vendor[\\/](node|j?ruby-.*|bundle)[\\/]/
        ]
        vendor: (path)->
            if hasOwn.call cache, path
                return cache[path]

            res = cache[path] = isVendorPath.test path
            return res if not res

            # components with {umd:true} should not be considered as client module

            if m = /^bower_components[\/\\]([^\/\\]+)/.exec(path)
                component = m[1]
                try
                    json = require "./bower_components/#{component}/.bower.json"
                    return cache[path] = !json.umd
                catch e
                    try
                        json = require "./bower_components/#{component}/bower.json"
                        return cache[path] = !json.umd

            if m = /^components[\/\\]([^\/\\]+)/.exec(path)
                component = m[1]
                try
                    json = require "./components/#{component}/component.json"
                    return cache[path] = !json.umd

            cache[path] = res

cache = {}
isVendorPath = exports.config.files.javascripts.joinTo['javascripts/vendor.js']
_isVendor = exports.config.conventions.vendor
nameCleaner = exports.config.modules.nameCleaner
isCustomUmdModule = exports.config.modules.isCustomUmdModule
