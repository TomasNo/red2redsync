require 'rubygems'
require 'open-uri'
require 'json'
class Sync1Controller < ApplicationController
  unloadable
  def index
	end

  def projsync
		error_message=nil
	

		adress = params["nil_class"]["adress"]
		project_id = params["nil_class"]["project_id"]
		
		project=Project.find_by_identifier("hmmtadyjenejakyindentifikacniklic")
		if project==nil   
			flash[:notice]="This project doesn't exist in your database"
			return 1
		end

#zacatek wiki, neni doladen prevod vseho hlavne zarazky a cislovani a asi vicenasobny vyskyt odkazu
#pokud neni wiki melo by se pokracovat v synchronizaci ostatnich udaju TODO , god know how to do this fuck...

		begin
		page=open("http://demo.redmine.org/projects/ahojda/wiki").read
		rescue =>error
		flash[:error]= error.message
		return 1
		end
#attachments aktualizace

	#ziskani adresy k ziskani priloh a datum vytvoreni, abychom overili, ze se jedna o novejsi soubor
		attachments_content=page.scan(/<div class="attachments">.*?<\/div>/m)
	#	attachments_date=attachments_content.collect{|x| x=x.scan(/<span class="author">.*?,.*?<\/span>/)}
	#	attachments_date[0].collect!{|x| x.gsub!(/<.*?>.*?,* /,'')}   
	# datum zyskam z rest api a stejne i vse ostatni KURVA! :D	
	#pokud jsou nejake prilohy	
	if(attachments_content[0]!=nil)
			attachments_content.collect!{ |x| x=x.scan(/\/attachments\/.*?\/.*?" class/)} 
			attachments_id=attachments_content[0].collect{|x| x=x.scan(/\/[0-9]*\//)}
		#z nejakeho duvodu se to tady musi prevest na string dont know why :o)
			attachments_id.collect!{|x| x=x.to_s}
				attachments_id.collect!{|x| 
				x=x.gsub(/\//,'')}
	#ziskani objektu z rest api attachments
			attachments_object=attachments_id.collect{|x| x=open("http://demo.redmine.org/attachments/#{x}.json").read
				x=JSON.parse(x)}
	#na zaklade data dochazi k synchronizaci souboru
			attachments_object.collect{|x| 
				actual_attach=Attachment.find_by_container_type_and_container_id_and_filename("WikiPage",project.id,x["attachment"]["filename"])
				if (actual_attach == nil || actual_attach["created_on"].to_s.gsub(/\D/,'')<x["attachment"]["created_on"].gsub(/\D/,''))
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
			puts "souborovy sync"
					#prehrani dat do tabulky o soboru , zmena created_on a filesize, description ... hash?...diskfilename?..
					actual_attach.filesize=x["attachment"]["filesize"].to_i
					actual_attach.description=x["attachment"]["description"]
					actual_attach.content_type=x["attachment"]["content_type"]
					actual_attach.container_type=x["attachment"]["container_type"]
					actual_attach.container_id=project.id
					actual_attach.author_id=User.current.id
					#vypocet hash			
					actual_attach.digest=Digest::MD5.hexdigest(File.read("files/#{actual_attach["disk_filename"]}")).to_s
				
        	if !(actual_attach.save)
						puts "piice"
						flash[:error]="File #{actual_attach["disk_filename"]} hasn't been updated"
					end

				end
			}
		end	
			
		
		
		

#overime si aktualnost wikipedie, ma se vubec aktualizovat
		history=open("http://demo.redmine.org/projects/ahojda/wiki/Wiki/history").read
			
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
			puts "wikisynchasbegun"
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
				error_message="Hmm wiki se nam neulozila"
			end
		end
#konec spracovani wiki
#zacatek spracovani issues
		content=open("http://demo.redmine.org/projects/ahojda/issues.json?limit=100").read
		issues=JSON.parse(content)
#otevrel se a vyparsoval obejkt s issue
#tady se nalezne project, ziskam jeho id a k nemu navazane issue abych je mohl synchronizovat
		
		issues["issues"].collect{|x|
			target_issue=Issue.find_by_subject_and_project_id(x["subject"],project.id)	
			
			#porovnani data , mali dojit k synchronizaci
			if (target_issue==nil | target_issue.updated_on.strftime("%s")<x["updated_on"].strftime("%s"))
				if (target_issue==nil)
					target_issue=Issue.new
					target_issue.id=Issue.find(:last).id+1
				end

			#souborovy sync k issue 
				issue_attachments=open("http://demo.redmine.org/issue/#{target_issue.id}.json?include=attachments&limit=100").read
				issue_attachments=JSON.parse(issue_attachments)
				issue_attachments=issue_attachments["attachments"]
				issues_attachments.collect{|x| 
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
						server_att.container_type=x["container_type"]
						server_att.container_id=project.id
						server_att.author_id=User.current.id
						#vypocet hash			
						server_att.digest=Digest::MD5.hexdigest(File.read("files/#{server_att["disk_filename"]}")).to_s
					
        		if !(server_att.save)
								puts "piice"
							flash[:error]="File #{server_att["disk_filename"]} hasn't been updated"
						end

			}
					
			
			target_issue["tracker_id"]=issues["issues"][i]["tracker"]["id"] if issues["issues"][i]["tracker"]
			target_issue["project_id"]=project.id
			target_issue["subject"]=issues["issues"][i]["subject"]
			target_issue["description"]=issues["issues"][i]["description"]
			target_issue["status_id"]=issues["issues"][i]["status"]["id"].to_i if issues["issues"][i]["status"]
			target_issue["assigned_to_id"]=issues["issues"][i]["assigned_to"]["id"].to_i if issues["issues"][i]["assigned_to"]
			target_issue["priority_id"]=issues["issues"][i]["priority"]["id"].to_i if issues["issues"][i]["priority"]
			target_issue["author_id"]=issues["issues"][i]["author"]["id"].to_i if issues["issues"][i]["author"]
			target_issue["created_on"]=issues["issues"][i]["created_on"]
			target_issue["updated_on"]=Time.current
			target_issue["start_date"]=issues["issues"][i]["start_date"]
			target_issue["done_ratio"]=issues["issues"][i]["done_ratio"]
			target_issue["due_date"]=issues["issues"][i]["due_date"]
			target_issue["category_id"]=issues["issues"][i]["category"]["id"].to_i  if issues["issues"][i]["category"]
			target_issue["fixed_version"]=issues["issues"][i]["fixed_version"]
			target_issue["estimated_hours"]=nil#zatim dame nil issues["issues"][i]["estimated_hours"]
			target_issue["parent_id"]=issues["issues"][i]["parent"]["id"].to_i if issues["issues"][i]["parents"]
			target_issue["root_id"]=issues["issues"][i]["root"]["id"].to_i if issues["issues"][i]["root"]
			target_issue["lft"]=issues["issues"][i]["lft"].to_i
			target_issue["rgt"]=issues["issues"][i]["rgt"].to_i
   		target_issue["is_private"]=false #zatim falseissues["issues"][i]["is_private"]
			puts i	
			if(!(target_issue.save)) 
			 flash[:error]="fuck thaht shit"
				break
			end
		end 
	}
				#	nejsou tu vsechny, nektere nejsou pristupne skrze rest api nebo se spatne vyparsovali
				#	 tady odecitam od velikosti issue, aby se aktualizovali, ty co uz jsou a vytvorili uplne nove
				#ted by se meli vytvorit nove polozky a  mozna smazat prebytecne <= prodiskutovat
				
	end
			redirect_to :action => 'index'
end


