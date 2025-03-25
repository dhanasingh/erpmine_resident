require_relative './app/lib/resident_hook'

Redmine::Plugin.register :erpmine_resident do
  name 'ERPmine Resident Management plugin'
  author 'Adhi Software Pvt Ltd'
  description 'This is a plugin for Resident Management'
  version '1.0'
  url 'http://www.redmine.org/plugins/wk-time'
  author_url 'http://www.adhisoftware.co.in/'

   settings(:partial => 'resident_settings',
           :default => {

	})

  Redmine::MenuManager.map :wktime_menu do |menu|
	  menu.push :apartment, { :controller => 'rmapartment', :action => 'index' }, :caption => :label_resident, :priority => 5
  end
end