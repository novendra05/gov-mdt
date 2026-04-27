fx_version 'cerulean'
game 'gta5'

author 'Antigravity'
description 'Government MDT for Qbox'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'web/assets/*.png'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory'
}
