class Sync1 < ActiveRecord::Base
  unloadable
end

class Project1 < ActiveResource::Base
	self.site="http://localhost:3000"
	self.user="admin"
	self.password="admin"
	self.element_name="project"
end

