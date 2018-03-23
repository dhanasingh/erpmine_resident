# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

get 'rmapartment/index', :to => 'rmapartment#index'

get 'rmresident/index', :to => 'rmresident#index'

get 'rmperformservice/index', :to => 'rmperformservice#index'

get 'rmperformservice/new', :to => 'rmperformservice#new'

get 'rmperformservice/getissues', :to => 'rmperformservice#getissues'

get 'rmperformservice/getactivities', :to => 'rmperformservice#getactivities'

get 'rmperformservice/getuserclients', :to => 'rmperformservice#getuserclients'

get 'rmperformservice/getuserissues', :to => 'rmperformservice#getuserissues'

get 'rmperformservice/getclients', :to => 'rmperformservice#getclients'

get 'rmperformservice/getusers', :to => 'rmperformservice#getusers'

get 'rmperformservice/deleterow', :to => 'rmperformservice#deleterow'

match 'rmperformservice/edit', :to => 'rmperformservice#edit', :via => [:get, :post]
		  
post 'rmperformservice/update', :to => 'rmperformservice#update'
		  
delete 'rmperformservice/destroy', :to => 'rmperformservice#destroy'

get 'rmperformservice/getTracker', :to => 'rmperformservice#getTracker'

delete 'rmperformservice/deleteEntries', :to => 'rmperformservice#deleteEntries'

get 'rmperformservice/export', :to => 'rmperformservice#export'


get 'rmapartment/edit', :to => 'rmapartment#edit'

get 'rmapartment/transfer', :to => 'rmapartment#transfer'

post 'rmapartment/update', :to => 'rmapartment#update'

delete 'rmapartment/destroy', :to => 'rmapartment#destroy'

get 'rmresident/edit', :to => 'rmresident#edit'

post 'rmresident/update', :to => 'rmresident#update'

get 'rmresident/newresidentservice', :to => 'rmresident#newresidentservice'

get 'rmresident/updateresidentservice', :to => 'rmresident#updateresidentservice'

delete 'rmresident/destroy', :to => 'rmresident#destroy'

get 'rmapartment/movein', :to => 'rmapartment#movein'

get 'rmapartment/locationApartments', :to => 'rmapartment#locationApartments'

get 'rmapartment/apartmentBeds', :to => 'rmapartment#apartmentBeds'

get 'rmapartment/bedRate', :to => 'rmapartment#bedRate'

get 'rmapartment/residentTransfer', :to => 'rmapartment#residentTransfer'

get 'rmapartment/moveOut', :to => 'rmapartment#moveOut'