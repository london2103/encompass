#!/usr/bin/env python
# Copyright(C) 2012 thomasv@gitorious

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public
# License along with this program.  If not, see
# <http://www.gnu.org/licenses/agpl.html>.

import argparse
import ConfigParser
import logging
import socket
import sys
import time
import threading
import json
import os
import imp


if os.path.dirname(os.path.realpath(__file__)) == os.getcwd():
    imp.load_module('encompassmercury', *imp.find_module('src'))
  

from encompassmercury import storage, utils
from encompassmercury.processor import Dispatcher, print_log
from encompassmercury.server_processor import ServerProcessor
from encompassmercury.blockchain_processor import BlockchainProcessor
from encompassmercury.stratum_tcp import TcpServer
from encompassmercury.stratum_http import HttpServer
import encompassmercury.chainparams as chainparams


logging.basicConfig()

if sys.maxsize <= 2**32:
    print "Warning: it looks like you are using a 32bit system. You may experience crashes caused by mmap"

if os.getuid() == 0:
    print "Do not run this program as root!"
    print "Run the install script to create a non-privileged user."
    sys.exit()

def attempt_read_config(config, filename):
    try:
        with open(filename, 'r') as f:
            config.readfp(f)
    except IOError:
        pass

def load_banner(config):
    try:
        with open(config.get('server', 'banner_file'), 'r') as f:
            config.set('server', 'banner', f.read())
    except IOError:
        pass

def create_config(filename=None):
    config = ConfigParser.ConfigParser()
    # set some defaults, which will be overwritten by the config file
    config.add_section('server')
    config.set('server', 'banner', 'Welcome to Encompass!')
    config.set('server', 'banner_file', '/etc/encompass.banner')
    config.set('server', 'host', 'localhost')
    config.set('server', 'electrum_rpc_port', '8000')
    config.set('server', 'report_host', '')
    config.set('server', 'stratum_tcp_port', '50001')
    config.set('server', 'stratum_http_port', '')
    config.set('server', 'stratum_tcp_ssl_port', '50002')
    config.set('server', 'stratum_http_ssl_port', '')
    config.set('server', 'report_stratum_tcp_port', '')
    config.set('server', 'report_stratum_http_port', '')
    config.set('server', 'report_stratum_tcp_ssl_port', '')
    config.set('server', 'report_stratum_http_ssl_port', '')
    config.set('server', 'ssl_certfile', '')
    config.set('server', 'ssl_keyfile', '')
    config.set('server', 'irc', 'no')
    config.set('server', 'irc_nick', '')
    config.set('server', 'coin', '')
    config.set('server', 'logfile', '/var/log/encompass-mercury.log')
    config.set('server', 'donation_address', '')
    config.set('server', 'max_subscriptions', '10000')

    config.add_section('leveldb')
    config.set('leveldb', 'path', '/dev/shm/encompass_db')
    config.set('leveldb', 'pruning_limit', '100')

    # set network parameters
    config.add_section('network')
    config.set('network', 'type', 'bitcoin_main')

    # try to find the config file in the default paths
    if not filename:
        for path in ('/etc/', ''):
            filename = path + 'encompass-mercury.conf'
            if os.path.isfile(filename):
                break

    if not os.path.isfile(filename):
        print 'could not find encompass configuration file "%s"' % filename
        sys.exit(1)

    attempt_read_config(config, filename)

    load_banner(config)

    return config

def update_config_with_coin(config, coin):
    # leveldb path
    db_path = config.get('leveldb', 'path')
    if not db_path.endswith('/'):
        db_path = ''.join([ db_path, '/' ])
    db_path = ''.join([ db_path, coin ])
    config.set('leveldb', 'path', db_path)
    try:
        coind_user = config.get(coin, 'coind_user')
        coind_pass = config.get(coin, 'coind_password')
        coind_host = config.get(coin, 'coind_host')
        coind_port = config.get(coin, 'coind_port')
    except (ConfigParser.NoSectionError, ConfigParser.NoOptionError):
        print('Could not get coind options from [{}] section of config.'.format(coin))
        sys.exit(1)
    config.set('bitcoind', 'bitcoind_user', coind_user)
    config.set('bitcoind', 'bitcoind_password', coind_pass)
    config.set('bitcoind', 'bitcoind_host', coind_host)
    config.set('bitcoind', 'bitcoind_port', coind_port)

def run_rpc_command(params, electrum_rpc_port):
    cmd = params[0]
    import xmlrpclib
    server = xmlrpclib.ServerProxy('http://localhost:%d' % electrum_rpc_port)
    func = getattr(server, cmd)
    r = func(*params[1:])
    if cmd == 'sessions':
        now = time.time()
        print 'type           address         sub  version  time'
        for item in r:
            print '%4s   %21s   %3s  %7s  %.2f' % (item.get('name'),
                                                   item.get('address'),
                                                   item.get('subscriptions'),
                                                   item.get('version'),
                                                   (now - item.get('time')),
                                                   )
    else:
        print json.dumps(r, indent=4, sort_keys=True)


def cmd_banner_update():
    load_banner(dispatcher.shared.config)
    return True

def cmd_getinfo():
    return {
        'chain': chainparams.get_active_chain().code,
        'blocks': chain_proc.storage.height,
        'peers': len(server_proc.peers),
        'sessions': len(dispatcher.request_dispatcher.get_sessions()),
        'watched': len(chain_proc.watched_addresses),
        'cached': len(chain_proc.history_cache),
        }

def cmd_sessions():
    return map(lambda s: {"time": s.time,
                          "name": s.name,
                          "address": s.address,
                          "version": s.version,
                          "subscriptions": len(s.subscriptions)},
               dispatcher.request_dispatcher.get_sessions())

def cmd_numsessions():
    return len(dispatcher.request_dispatcher.get_sessions())

def cmd_peers():
    return server_proc.peers.keys()

def cmd_numpeers():
    return len(server_proc.peers)

def cmd_debug(s):
    if s:
        try:
            result = str(eval(s))
        except:
            result = "error"
        return result


def get_port(config, name):
    try:
        return config.getint('server', name)
    except:
        return None

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--conf', metavar='path', default=None, help='specify a configuration file')
    parser.add_argument('--coin', metavar='currency', default='CDN', help='coin to run')
    parser.add_argument('command', nargs='*', default=[], help='send a command to the server')
    args = parser.parse_args()

    config = create_config(args.conf)
    logfile = config.get('server', 'logfile')
    utils.init_logger(logfile)
    host = config.get('server', 'host')
    electrum_rpc_port = get_port(config, 'electrum_rpc_port')
    stratum_tcp_port = get_port(config, 'stratum_tcp_port')
    stratum_http_port = get_port(config, 'stratum_http_port')
    stratum_tcp_ssl_port = get_port(config, 'stratum_tcp_ssl_port')
    stratum_http_ssl_port = get_port(config, 'stratum_http_ssl_port')
    ssl_certfile = config.get('server', 'ssl_certfile')
    ssl_keyfile = config.get('server', 'ssl_keyfile')

    chainparams.init_chains()
    chainparams.set_active_chain(args.coin)

    update_config_with_coin(config, args.coin.lower())

    if ssl_certfile is '' or ssl_keyfile is '':
        stratum_tcp_ssl_port = None
        stratum_http_ssl_port = None

    if len(args.command) >= 1:
        try:
            run_rpc_command(args.command, electrum_rpc_port)
        except socket.error:
            print "server not running"
            sys.exit(1)
        sys.exit(0)

    try:
        run_rpc_command(['getpid'], electrum_rpc_port)
        is_running = True
    except socket.error:
        is_running = False

    if is_running:
        print "server already running"
        sys.exit(1)


    print_log("Starting Encompass-Mercury server on", host)

    # Create hub
    dispatcher = Dispatcher(config)
    shared = dispatcher.shared

    # handle termination signals
    import signal
    def handler(signum = None, frame = None):
        print_log('Signal handler called with signal', signum)
        shared.stop()
    for sig in [signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT]:
        signal.signal(sig, handler)


    # Create and register processors
    chain_proc = BlockchainProcessor(config, shared)
    dispatcher.register('blockchain', chain_proc)

    server_proc = ServerProcessor(config, shared)
    dispatcher.register('server', server_proc)

    transports = []
    # Create various transports we need
    if stratum_tcp_port:
        tcp_server = TcpServer(dispatcher, host, stratum_tcp_port, False, None, None)
        transports.append(tcp_server)

    if stratum_tcp_ssl_port:
        tcp_server = TcpServer(dispatcher, host, stratum_tcp_ssl_port, True, ssl_certfile, ssl_keyfile)
        transports.append(tcp_server)

    if stratum_http_port:
        http_server = HttpServer(dispatcher, host, stratum_http_port, False, None, None)
        transports.append(http_server)

    if stratum_http_ssl_port:
        http_server = HttpServer(dispatcher, host, stratum_http_ssl_port, True, ssl_certfile, ssl_keyfile)
        transports.append(http_server)

    for server in transports:
        server.start()

    

    from SimpleXMLRPCServer import SimpleXMLRPCServer
    server = SimpleXMLRPCServer(('localhost', electrum_rpc_port), allow_none=True, logRequests=False)
    server.register_function(lambda: os.getpid(), 'getpid')
    server.register_function(shared.stop, 'stop')
    server.register_function(cmd_getinfo, 'getinfo')
    server.register_function(cmd_sessions, 'sessions')
    server.register_function(cmd_numsessions, 'numsessions')
    server.register_function(cmd_peers, 'peers')
    server.register_function(cmd_numpeers, 'numpeers')
    server.register_function(cmd_debug, 'debug')
    server.register_function(cmd_banner_update, 'banner_update')
    server.socket.settimeout(1)
 
    while not shared.stopped():
        try:
            server.handle_request()
        except socket.timeout:
            continue
        except:
            shared.stop()

    server_proc.join()
    chain_proc.join()
    print_log("Encompass-Mercury Server stopped")
