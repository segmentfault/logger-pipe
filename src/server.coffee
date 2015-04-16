
argv = require 'optimist'
    .default 'p', 514
    .default 'h', '0.0.0.0'
    .default 't', 9922
    .default 's', '0.0.0.0'
    .default 'l', 64
    .argv
net = require 'net'
dgram = require 'dgram'
winston = require 'winston'
Channels = require './channels'
syslog = require 'glossy'
    .Parse

# create logger object
logger = new winston.Logger
    transports: [
        new winston.transports.Console
            handleExceptions:   yes
            level:              'info'
            prettyPrint:        yes
            colorize:           yes
            timestamp:          yes
    ]
    exitOnError: no
    levels:
        info:   0
        warn:   1
        error:  3
    colors:
        info:   'green'
        warn:   'yellow'
        error:  'red'

# create udp host
type = if net.isIPv4 argv.h then 'udp4' else 'udp6'
udp = dgram.createSocket type
channels = new Channels (parseInt argv.l)

udp.bind argv.p, argv.h, ->
    logger.info "log server is listening at #{argv.h}:#{argv.p}"

    # receive message
    udp.on 'message', (msg, info) ->
        logger.info "received #{msg.length} bytes from #{info.address}:#{info.port}"

        raw = msg.toString 'utf8', 0

        # parse syslog
        syslog.parse raw, (log) ->
            match = log.host + (if log.pid? then "[#{log.pid}]" else '')
            aPos = (log.originalMessage.indexOf match) + match.length
            sub = log.originalMessage.substring aPos
            bPos = sub.indexOf ':'

            if bPos > 0
                log.tag = sub.substring 1, bPos
                
                matched = log.tag.match /^(\w+)\[(\d+)\]$/i
                if matched?
                    log.tag = matched[1]
                    log.pid = matched[2]

                log.message = sub.substring bPos + 2

            channels.send log


tcp = net.createServer (c) ->
    logger.info "#{c.remoteAddress}:#{c.remotePort} connected"
    listener = null
    
    lists = channels.availables()
    c.write JSON.stringify lists

    address = c.remoteAddress
    port = c.remotePort
    c.on 'close', ->
        logger.info "#{address}:#{port} disconnected"
        if listener?
            [name, cb] = listener
            channels.remove name, cb
            listener = null

    c.on 'error', ->
        if listener?
            [name, cb] = listener
            channels.remove name, cb
            listener = null
    
    c.on 'data', (data)->
        name = data.toString()
            .replace /^\s*(.+)\s*$/, '$1'

        if lists[name]?
            logger.info "#{c.remoteAddress}:#{c.remotePort} is now listening at #{name}"
            
            cb = (log) ->
                c.write JSON.stringify log
            listener = [name, cb]
            channels.listen name, cb


tcp.listen argv.t, argv.s, ->
    logger.info "transport server is listening at #{argv.s}:#{argv.t}"

