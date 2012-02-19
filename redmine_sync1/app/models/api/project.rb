require 'active_resource'

module api

	class Project1 < ActiveResource::Base
		self.site="demo.redmine.org"
		self.element_name="project"
	end


end
