
argv = require 'optimist'
    .default 'p', 9922
    .default 'h', '127.0.0.1'
    .default 'c', null
    .default 'ssh-host', null
    .default 'ssh-user', 'root'
    .default 'ssh-key', null
    .default 'ssh-password', null
    .argv
net = require 'net'
winston = require 'winston'
ssh = require 'ssh2'
fs = require 'fs'

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


# process client
handler = (client) ->
    first = yes

    client.on 'data', (data) ->
        try
            info = JSON.parse data
        catch e
            return logger.error e

        if first
            first = no
            if argv.c?
                if not info[argv.c]?
                    client.end()
                    throw new Error "#{argv.c} is not an available channel"
                else
                    client.write argv.c
                    logger.info "listening at #{argv.c}"
            else
                client.end()
                console.log "Available Channels:\n"
                for name, time of info
                    console.log "#{name}\t\t#{time}"
                process.exit 1
        else
            console.log "#{info[0]}: #{info[1]}"

if argv['ssh-host']?
    parts = argv['ssh-host'].split ':'
    options =
        host: parts[0]
        port: if parts[1]? then parseInt parts[1] else 22
        username: argv['ssh-user']

    if argv['ssh-key']?
        options.privateKey = fs.readFileSync argv['ssh-key']
    else
        options.passowrd = argv['ssh-password']

    conn = new ssh.Client
    conn.on 'ready', ->
        logger.info "ssh connected to #{options.host}:#{options.port}"
        conn.forwardOut '127.0.0.1', 9933, argv.h, argv.p, (err, stream) ->
            throw err if err?
            logger.info "connected to #{argv.h}:#{argv.p}"
            handler stream
    .connect options

else
    client = net.connect argv.p, argv.h, ->
        logger.info "connected to #{argv.h}:#{argv.p}"

    handler client

