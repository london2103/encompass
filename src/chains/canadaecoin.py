import cryptocur

class Currency(cryptocur.CryptoCur):
    p2pkh_version = 28
    p2sh_version = 5
    genesis_hash = '863626dadaef221e2e2f30ff3dacae44cabdae9e0028058072181b3fb675d94a'
    
    coin_name = 'Canada eCoin'
    code = 'CDN'

    irc_nick_prefix = 'EC_'
    irc_channel = '#electrum-cdn'