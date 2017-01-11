from setuptools import setup

setup(
    name="encompass-mercury",
    version="0.9",
    scripts=['run_encompass_mercury','encompass-mercury'],
    install_requires=['plyvel','jsonrpclib', 'irc>=11','coinhash==1.1.4'],
    package_dir={
        'encompassmercury':'src'
        },
    py_modules=[
        'encompassmercury.__init__',
        'encompassmercury.chainparams',
        'encompassmercury.utils',
        'encompassmercury.storage',
        'encompassmercury.deserialize',
        'encompassmercury.blockchain_processor',
        'encompassmercury.server_processor',
        'encompassmercury.processor',
        'encompassmercury.version',
        'encompassmercury.ircthread',
        'encompassmercury.stratum_tcp',
        'encompassmercury.stratum_http',
        'encompassmercury.chains.__init__',
        'encompassmercury.chains.cryptocur',
        'encompassmercury.chains.cloak',
    ],
    description="Multi-Coin Electrum Server",
    author="Tyler Willis",
    author_email="kefkius@maza.club",
    license="GNU Affero GPLv3",
    url="https://github.com/kefkius/encompass-mercury/",
    long_description="""Multi-Coin Server for the Encompass Lightweight Wallets"""
)


