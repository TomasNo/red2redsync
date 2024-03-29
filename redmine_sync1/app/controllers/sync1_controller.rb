require 'rubygems'
require 'open-uri'
require 'json'
class Sync1Controller < ApplicationController
  unloadable
  def index
	end

  def projsync
		error_message=''
	
		#form processing
		adress = params["nil_class"]["adress"]
		project_identifier = params["nil_class"]["project_id"]
		adress="http://demo.redmine.org"
		project_identifier="ahojda"
		project=Project.find_by_identifier("hmmtadyjenejakyindentifikacniklic")
		if project==nil   
			flash[:notice]="This project doesn't exist in your database"
			return 1
		end

#pro wiki neni podpora rest api => parsovani webu, zacatek wiki
		begin
		page=open(adress+"/projects/"+project_identifier+"/wiki").read
		rescue =>error
		flash[:error]= error.message
		return 1
		end
#attachments aktualizace

	#ziskani adresy k ziskani priloh a datum vytvoreni, abychom overili, ze se jedna o novejsi soubor
		attachments_content=page.scan(/<div class="attachments">.*?<\/div>/m)
	# datum zyskam z rest api a stejne i vse ostatni 	
	#pokud jsou nejake prilohy	
	if(attachments_content[0]!=nil)
			attachments_content.collect!{ |x| x=x.scan(/\/attachments\/.*?\/.*?" class/)} 
			attachments_id=attachments_content[0].collect{|x| x=x.scan(/\/[0-9]*\//)}
			attachments_id.collect!{|x| x=x.to_s}
				attachments_id.collect!{|x| 
				x=x.gsub(/\//,'')}
	#ziskani objektu z rest api attachments
			attachments_object=attachments_id.collect{|x| x=open(adress+"/attachments/#{x}.json").read
				x=JSON.parse(x)}
	#na zaklade data dochazi k synchronizaci souboru
			attachments_object.collect{|x| 
				actual_attach=Attachment.find_by_container_type_and_container_id_and_filename("WikiPage",project.id,x["attachment"]["filename"])
				if (actual_attach == nil || actual_attach["created_on"].strftime("%Y/%m/%d %H:%M:%S").gsub("/+.*",'')<x["attachment"]["created_on"])
					#nahrani souboru
					#pokud soubor jeste vubec neexistuje
					if (actual_attach ==nil)
						time=Time.current
						source_file=time.strftime("%s_"+x["attachment"]["filename"]) #tady muze zrejme v nejakem extremni pripade dojit ke kolizi je treba zjisti jak presne si to uklada redmine TODO
						actual_attach=Attachment.new
						actual_attach.disk_filename=source_file
						actual_attach.filename=x["attachment"]["filename"]
						actual_attach.id=Attachment.find(:last).id+1

					else
						source_file=actual_attach.disk_filename 
					end

					File.open("files/"+source_file, "wb") do |saved_file|
  					open(x["attachment"]["content_url"]) do |read_file|
    					saved_file.write(read_file.read)
  					end
					end
					#prehrani dat do tabulky o soboru , zmena created_on a filesize, description ... hash?...diskfilename?..
					actual_attach.filesize=x["attachment"]["filesize"].to_i
					actual_attach.description=x["attachment"]["description"]
					actual_attach.content_type=x["attachment"]["content_type"]
					actual_attach.container_type="WikiPage"
					actual_attach.container_id=project.id
					actual_attach.created_on=x["attachment"]["created_on"]
					actual_attach.author_id=User.current.id
					#vypocet hash			
					actual_attach.digest=Digest::MD5.hexdigest(File.read("files/#{actual_attach["disk_filename"]}")).to_s
				
        	if !(actual_attach.save)
						error_message=error_message+"File  #{actual_attach["disk_filename"]} hasn't been updated, wiki part\n"
					end

				end
			}
		end	
			
		
		
		

#overime si aktualnost wikipedie, ma se vubec aktualizovat
#opet parsing webu
		history=open(adress+"/projects/"+project_identifier+"/wiki/Wiki/history").read
		history=history.scan(/<td class="updated_on">.*?<\/td>/)
		
		history[0].gsub!(/<.*?>/,'')
		if( history[0][17,18]=="pm")
			history[0].gsub!(/\D/,'')
			a=(history[0][8]-48)*10+(history[0][9]-48)+12 #48 reprezentuje '0'=> je treba zjisti jak se provadi konverze na char a z5	
		history[0][9]=a
		else
		history[0].gsub!(/\D/,'')
		end
	#nalezeni odpovidajici domaci wiki
		wiki=WikiContent.find(project.id)
		wiki_update=wiki["updated_on"]
	puts "stari wikin je #{history[0]} a #{wiki_update.strftime("%m%d%Y%H%M")}"	
		#spusteni synchronizace pokud se na webu naleza nejnovejsi verze	
		if (wiki==nil || history[0] > wiki_update.strftime("%m%d%Y%H%M"))
#wik_attachments
			wiki_content=page.scan(/<div class="wiki wiki-page">.*?<\/div>/m)

#nahrazeni nadpisu za h[123]. a taky prevod na string
		  wiki_content=wiki_content.to_s
			wiki_content.gsub!(/<h1 >/,'h1. ')
			wiki_content.gsub!(/<h2 >/,'h2. ')
			wiki_content.gsub!(/<h3 >/,'h3. ')
#tady se br prevadi na mezery		
			wiki_content.gsub!(/<br \/>/,"\n")
#tady se prevadi vsechny specialni formatovani wiki na znaky pouzite v databazi
			wiki_content.gsub!(/<\/*strong>/,'*')
			wiki_content.gsub!(/<\/*em>/,'_')
			wiki_content.gsub!(/<ul><li>/,'* ')
			wiki_content.gsub!(/<\/li>/,'')
			wiki_content.gsub!(/<\/ul>/,'')
			wiki_content.gsub!(/<\/*ins>/,'+')
			wiki_content.gsub!(/<\/*del>/,'-')
			wiki_content.gsub!(/<\/*?code>/,'@')
	#quote
			wiki_content.gsub!(/<blockquote>/,'> ')
			wiki_content.gsub!(/<\/blockquote>/,'')
	#odkaz na wiki
			nazev_odkazu=wiki_content.scan(/<a href.*?class="wiki-page new">.*?<\/a>/m)
			if nazev_odkazu[0]!=nil then
				nazev_odkazu[0].gsub!(/<.*?>/,'')
				wiki_content.gsub!(/<a href.*?class="wiki-page new">#{nazev_odkazu}<\/a>/,"[[#{nazev_odkazu}]]")
			end
		#obrazek	
			nazev_odkazu_img=wiki_content.scan(/<img src=".*?" \/>/)
			if nazev_odkazu_img[0]!=nil then

				nazev_odkazu_img[0].gsub!(/<img src="/,'')
				nazev_odkazu_img[0].gsub(/" \/>/,'')
				wiki_content.gsub!(/<img src.*?>/,'!'+nazev_odkazu_img+'!')
			end
#prevod vsech tagu , ktere se do ted neodstranili
			wiki_content.gsub!(/<.*?>/,'')
#odstraneni tabulatoru , nejakym zahadnym zpusobem se tam vyskytuji :D
			wiki_content.gsub!(/\t/,'')
#odstraneni nejakeho &para; bordelu
			wiki_content.gsub!(/&para;/,'');
#nalezeni odpovidajici domaci wiki
			wiki=WikiContent.find(project.id)	
#u wikin musis upravit dve tabulky content a page		
			if (wiki==nil) #pokud wikina neexistuje vytvori se nova
				wiki=WikiContent.new
		  	wiki["id"]=WikiContent.find(:last)["id"]+1
				wiki["page_id"]=WikiContent.find(:last)["page_id"]+1
				wiki["author_id"]=User.current["id"]
				wiki_page=WikiPage.new		
				wiki_page["id"]=WikiPage.find(:last)["id"]+1
				wiki_page["wiki_id"]=project.id
				wiki_page["title"]="Wiki"
				wiki_page["created_on"]=Time.current
				wiki_page["updated_on"]=Time.current
				wiki_page.save
			end
			wiki["text"]=wiki_content
			#wiki["comments"]=wiki_commment
			wiki["updated_on"]=Time.current		
			if (!(wiki.save))
				error_message=error_message+"Wiki hasn't been saved\n"
			end
		end
#konec spracovani wiki
#zacatek spracovani issues
		content=open(adress+"/projects/"+project_identifier+"/issues.json?limit=100").read
		issues=JSON.parse(content)
#otevrel se a vyparsoval obejkt s issue
		puts"vypis"
		issues["issues"].collect{|x|
			target_issue=Issue.find_by_subject_and_project_id(x["subject"],project.id)	
			puts "zacala synchronizace issue"	
			#porovnani data , mali dojit k synchronizaci
			if (target_issue==nil || target_issue.updated_on.strftime("%s")<x["updated_on"].strftime("%s"))
				if (target_issue==nil)
					puts "vytvarim nove issue"
					target_issue=Issue.new
					target_issue.id=Issue.find(:last).id+1
				end
			#souborovy sync k issue 
				issue_attachments=open(adress+"/issues/#{x["id"]}.json?include=attachments&limit=100").read
				
				issue_attachments=JSON.parse(issue_attachments)
				issue_attachments=issue_attachments["attachments"]
				if (issue_attachments!=nil)
					issue_attachments.collect{|x| 
						server_att=Attachment.find_by_container_type_and_container_id_and_filename("Issue",project.id,x["filename"])
						
						if (server_att==nil || server_att.created_on.strftime.strftime("%s") < x["created_on"].strftime("%s"))

							if server_att==nil
								time=Time.current
								source_file=time.strftime("%s_"+x["filename"])
								server_att=Attachment.new
								server_att.id=Attachment.find(:last).id+1
								server_disk_filename=source_file
							else
								source_file=server_att.disk_filename
							end
					
							File.open("files/"+source_file, "wb") do |saved_file|
  							open(x["content_url"]) do |read_file|
    							saved_file.write(read_file.read)
  							end
							end
						 	server_att.filesize=x["filesize"].to_i
							server_att.description=x["description"]
							server_att.content_type=x["content_type"]
							server_att.container_type="Issue"
							server_att.container_id=project.id
							server_att.author_id=User.current.id
							#vypocet hash			
							server_att.digest=Digest::MD5.hexdigest(File.read("files/#{server_att["disk_filename"]}")).to_s
						
        		if !(server_att.save)
								error_message=error_message+"File #{server_att["disk_filename"]} hasn't been updated \n"
						else
								puts "attachment se neulozil"
						end
					end
				}
					
			
			target_issue["tracker_id"]=x["tracker"]["id"] if x["tracker"]
			target_issue["project_id"]=project.id
			target_issue["subject"]=x["subject"]
			target_issue["description"]=x["description"]
			target_issue["status_id"]=x["status"]["id"].to_i if x["status"]
			target_issue["assigned_to_id"]=x["assigned_to"]["id"].to_i if x["assigned_to"]
			target_issue["priority_id"]=x["priority"]["id"].to_i if x["priority"]
			target_issue["author_id"]=x["author"]["id"].to_i if x["author"]
			target_issue["created_on"]=x["created_on"]
			target_issue["updated_on"]=Time.current
			target_issue["start_date"]=x["start_date"]
			target_issue["done_ratio"]=x["done_ratio"]
			target_issue["due_date"]=x["due_date"]
			target_issue["category_id"]=x["category"]["id"].to_i  if x["category"]
			target_issue["fixed_version"]=x["fixed_version"]
			target_issue["estimated_hours"]=nil#zatim dame nil x["estimated_hours"]
			target_issue["parent_id"]=x["parent"]["id"].to_i if x["parents"]
			target_issue["root_id"]=x["root"]["id"].to_i if x["root"]
			target_issue["lft"]=x["lft"].to_i
			target_issue["rgt"]=x["rgt"].to_i
   		target_issue["is_private"]=false #zatim falsex["is_private"]
			if(!(target_issue.save)) 
			 error_message=error_message+"Issues havent been synchronized\n"
			else
				puts "issue ulozeno"
			end
	end
end
		}
	
				
			if (error_message)!=''
				flash[:error]=error_message
				puts "neco se pokazilo"
			else
			puts "vse ok"
			end
			redirect_to :action => 'index'
	end

end
