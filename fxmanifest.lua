fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fr_compmachine'
description 'A compensation system to help admins reimburse items to players who have lost their items unfairly'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/logs.lua',
    'server/server.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
}