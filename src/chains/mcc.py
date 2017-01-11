import cryptocur

class Currency(cryptocur.CryptoCur):
    p2pkh_version = 50
    p2sh_version = 5
    genesis_hash = 'e84b6b9b001a30fea5d0d5d6be87af1475fb7a06cd6afa232c241d98d9470c87'
    
    coin_name = 'Marketers Coop Currency'
    code = 'MCC'

    irc_nick_prefix = 'EC_'
    irc_channel = '#electrum-mcc'