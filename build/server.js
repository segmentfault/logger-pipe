// Generated by CoffeeScript 1.7.1
(function() {
  var Channels, argv, channels, dgram, logger, net, syslog, tcp, type, udp, winston;

  argv = require('optimist')["default"]('p', 514)["default"]('h', '0.0.0.0')["default"]('t', 9922)["default"]('s', '0.0.0.0')["default"]('l', 64).argv;

  net = require('net');

  dgram = require('dgram');

  winston = require('winston');

  Channels = require('./channels');

  syslog = require('glossy').Parse;

  logger = new winston.Logger({
    transports: [
      new winston.transports.Console({
        handleExceptions: true,
        level: 'info',
        prettyPrint: true,
        colorize: true,
        timestamp: true
      })
    ],
    exitOnError: false,
    levels: {
      info: 0,
      warn: 1,
      error: 3
    },
    colors: {
      info: 'green',
      warn: 'yellow',
      error: 'red'
    }
  });

  type = net.isIPv4(argv.h) ? 'udp4' : 'udp6';

  udp = dgram.createSocket(type);

  channels = new Channels(parseInt(argv.l));

  udp.bind(argv.p, argv.h, function() {
    logger.info("log server is listening at " + argv.h + ":" + argv.p);
    return udp.on('message', function(msg, info) {
      var raw;
      logger.info("received " + msg.length + " bytes from " + info.address + ":" + info.port);
      raw = msg.toString('utf8', 0);
      return syslog.parse(raw, function(log) {
        var aPos, bPos, cPos, match, matched, sub;
        match = log.host + (log.pid != null ? "[" + log.pid + "]" : '');
        aPos = (log.originalMessage.indexOf(match)) + match.length;
        sub = log.originalMessage.substring(aPos + 1);
        bPos = sub.indexOf(':');
        cPos = sub.indexOf(' ');
        if (bPos > 0 && cPos > bPos) {
          log.tag = sub.substring(1, bPos);
          matched = log.tag.match(/^(\w+)\[(\d+)\]$/i);
          if (matched != null) {
            log.tag = matched[1];
            log.pid = matched[2];
          }
          log.message = sub.substring(bPos + 2);
        }
        return channels.send(log);
      });
    });
  });

  tcp = net.createServer(function(c) {
    var address, listener, lists, port;
    logger.info("" + c.remoteAddress + ":" + c.remotePort + " connected");
    listener = null;
    lists = channels.availables();
    c.write(JSON.stringify(lists));
    address = c.remoteAddress;
    port = c.remotePort;
    c.on('close', function() {
      var cb, name;
      logger.info("" + address + ":" + port + " disconnected");
      if (listener != null) {
        name = listener[0], cb = listener[1];
        channels.remove(name, cb);
        return listener = null;
      }
    });
    c.on('error', function() {
      var cb, name;
      if (listener != null) {
        name = listener[0], cb = listener[1];
        channels.remove(name, cb);
        return listener = null;
      }
    });
    return c.on('data', function(data) {
      var cb, name;
      name = data.toString().replace(/^\s*(.+)\s*$/, '$1');
      if (lists[name] != null) {
        logger.info("" + c.remoteAddress + ":" + c.remotePort + " is now listening at " + name);
        cb = function(log) {
          return c.write(JSON.stringify(log));
        };
        listener = [name, cb];
        return channels.listen(name, cb);
      }
    });
  });

  tcp.listen(argv.t, argv.s, function() {
    return logger.info("transport server is listening at " + argv.s + ":" + argv.t);
  });

}).call(this);
