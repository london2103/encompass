import cryptocur

class Currency(cryptocur.CryptoCur):
    p2pkh_version = 27
    p2sh_version = 85
    genesis_hash = '2d8251121940abce6e28df134c6432e8c5a00d59989a2451806c2778c3a06112'
    
    coin_name = 'Cloak Coin'
    code = 'CLOAK'

    irc_nick_prefix = 'EL_'
    irc_channel = '#electrum-cloak'