fx_version "cerulean"

description "A edited version of LegacyFuel with a animation and a ui design"
author "gachaa"
version '1.0.1'

lua54 'yes'

games {
  "gta5"
}

ui_page 'web/build/index.html'

-- shared_script '@es_extended/imports.lua' --Import this if you are using es_extended

client_scripts {
  'config.lua',
  "client/**/*"
}
server_script {
  'config.lua',
  "server/**/*"
}

files {
	'web/build/index.html',
	'web/build/**/*',
}

exports {
	'GetFuel',
	'SetFuel'
}