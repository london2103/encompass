import cryptocur

class Currency(cryptocur.CryptoCur):
    p2pkh_version = 73
    p2sh_version = 5
    genesis_hash = '322355644ddba5c56e82a5f74dd8a8c658d7cd12fe49ee78b18ac9249b982ff2'
    
    coin_name = 'Walcoin'
    code = 'WAL'

    irc_nick_prefix = 'EC_'
    irc_channel = '#electrum-wal'