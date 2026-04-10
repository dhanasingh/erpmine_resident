# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

get 'rmapartment/index', :to => 'rmapartment#index'

get 'rmresident/index', :to => 'rmresident#index'

get 'rmperformservice/index', :to => 'rmperformservice#index'

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

get 'rmincident/index', :to => 'rmincident#index'

get 'rmincident/edit', :to => 'rmincident#edit'

post 'rmincident/update', :to => 'rmincident#update'

delete 'rmincident/destroy', :to => 'rmincident#destroy'

get 'rmincident/get_resident_info', :to => 'rmincident#get_resident_info'

get 'rmincident/get_residents_by_location', :to => 'rmincident#get_residents_by_location'


get 'rmapartment/edit', :to => 'rmapartment#edit'

get 'rmapartment/transfer', :to => 'rmapartment#transfer'

post 'rmapartment/update', :to => 'rmapartment#update'

delete 'rmapartment/destroy', :to => 'rmapartment#destroy'

get 'rmresident/edit', :to => 'rmresident#edit'

post 'rmresident/update', :to => 'rmresident#update'

get 'rmresident/newresidentservice', :to => 'rmresident#newresidentservice'

post 'rmresident/updateresidentservice', :to => 'rmresident#updateresidentservice'

delete 'rmresident/destroy', :to => 'rmresident#destroy'

get 'rmresident/movein', :to => 'rmresident#movein'

get 'rmresident/locationApartments', :to => 'rmresident#locationApartments'

get 'rmresident/apartmentBeds', :to => 'rmresident#apartmentBeds'

get 'rmresident/bedRate', :to => 'rmresident#bedRate'

post 'rmresident/residentTransfer', :to => 'rmresident#residentTransfer'

post 'rmresident/moveOut', :to => 'rmresident#moveOut'

delete 'rmresident/residentservicedestroy', :to => 'rmresident#residentservicedestroy' 

post 'rmresident/moveInResident', :to => 'rmresident#moveInResident'

get 'rmevaluation/index', to: 'rmevaluation#index'

get 'rmresident/get_resident_tabs', :to => 'rmresident#get_resident_tabs'

get 'rmevaluation/edit', :to => 'rmevaluation#edit'

get 'rmevaluation/:id/edit', :to => 'rmevaluation#edit'

get 'rmevaluation/:id/survey_response', :to => 'rmevaluation#survey_response'

get 'rmevaluation/:id/survey_result', :to => 'rmevaluation#survey_result'

post 'rmevaluation/save_survey', :to => 'rmevaluation#save_survey'

post 'rmevaluation/update_survey', :to => 'rmevaluation#update_survey'

get 'rmevaluation/:id/survey', :to => 'rmevaluation#survey'

delete 'rmevaluation/:id', :to => 'rmevaluation#destroy'

post 'rmevaluation/close_current_response', :to => 'rmevaluation#close_current_response'

get 'rmevaluation/export', :to => 'rmevaluation#export'
