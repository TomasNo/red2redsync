class Ukoly < ActiveResource::Base
	unloadable
	self.site="demo.redmine.org"
	self.element_name="issue"
end
