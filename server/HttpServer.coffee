log4js = global.log4js or (global.log4js = require 'log4js')
logger = log4js.getLogger 'HttpServer'
sysPath = require 'path'
fs = require 'fs'

context = '/'

sendContents = (req, res, path, next)->
    url = req.path.substring(1)

    if /^app\b/.test(url) or (url is '' and not resource)
        _sendContents req, res, path, 'single', context
    else if /^web\b/.test url
        _sendContents req, res, path, 'classic', context
    else if resource
        resource = if resource is 'web' then 'classic' else 'single'
        _sendContents req, res, path, resource, context
    else
        next()
    return

_sendContents = (req, res, path, page, context)->
    filePath = sysPath.join path, 'index.' + page + '.html'
    fs.readFile filePath, (err, contents)->
        contents = contents.toString().replace /\b(href|src|data-main)="(?!https?:\/\/|\/)([^"]+)/g, "$1=\"#{context}$2"
        contents = contents.replace "{baseUrl: ''}", "{baseUrl: '#{context}'}"
        res.send contents
        return
    return true

exports.startServer = (port, path, callback)->
    path = sysPath.resolve __dirname, '..', path

    express = require 'express'
    app = express()

    # prefer using nginx or httpd for static files
    app.use express.static path

    app.get context + '*', (req, res, next)->
        sendContents req, res, path, next
        return

    http = require 'http'
    server = http.createServer app

    server.listen port, ->
        listenedIface = server.address()
        logger.info 'Server listening on', listenedIface

        if listenedIface.family is 'IPv6'
            log = (info, listenedIface)->
                logger.info "Visit http://[#{info.address}]:#{listenedIface.port}"
                return
        else
            log = (info, listenedIface)->
                logger.info "Visit http://#{info.address}:#{listenedIface.port}"
                return

        if listenedIface.address in ['0.0.0.0', '::']
            ifaces = require('os').networkInterfaces()
            for iface of ifaces
                for info in ifaces[iface]
                    if info.family is listenedIface.family
                        log info, listenedIface
        else
            logger.info "Visit http://#{listenedIface.address}:#{listenedIface.port}"

        process.on 'uncaughtException', (ex)->
            logger.error "Exception: #{ex.stack}"
            return

        callback() if 'function' is typeof callback
        return

    server
