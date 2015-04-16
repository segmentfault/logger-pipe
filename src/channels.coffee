
EventEmitter = require('events').EventEmitter

class Channels

    constructor: (limit) ->
        @event = new EventEmitter
        @event.setMaxListeners limit
        @lists = {}

    
    # send log
    send: (log) ->
        name = log.host + (if log.tag? then ':' + log.tag else '')
        @lists[name] = log.time
        @event.emit name, [log.time, log.message]

    
    # listen channels
    listen: (name, cb) ->
        @event.on name, cb


    # remove listener
    remove: (name, cb) ->
        @event.removeListener name, cb

    
    # get available channels
    availables: ->
        @lists


module.exports = Channels

