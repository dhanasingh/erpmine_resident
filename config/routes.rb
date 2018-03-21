# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

get 'rmapartment/index', :to => 'rmapartment#index'

get 'rmresident/index', :to => 'rmresident#index'

get 'rmperformservice/index', :to => 'rmperformservice#index'

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