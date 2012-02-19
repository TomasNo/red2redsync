require 'rubygems'
require 'active_resource'


class Projekt1 < ActiveResource::Base
	self.site="demo.redmine.org"
	self.user="betaalfa"
	self.password="betaalfa"
	self.element_name="project"
end
