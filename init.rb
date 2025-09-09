require_relative './lib/resident_hook'

Redmine::Plugin.register :erpmine_resident do
  name 'ERPmine Resident Management plugin'
  author 'Adhi Software Pvt Ltd'
  description 'This is a plugin for Resident Management'
  version '1.1'
  url 'https://www.erpmine.org/projects/resident/wiki/Resident'
  author_url 'http://www.adhisoftware.co.in/'

  settings(partial: 'resident_settings', default: {})
end