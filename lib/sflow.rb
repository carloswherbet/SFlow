
#!/usr/bin/ruby
begin
  require 'pry'
rescue LoadError
  # Gem loads as it should
end
require 'i18n'

require 'net/http'
require "pastel"
require "open3"
require "date"
require 'uri'
require 'config'

load 'tty_integration.rb'
load 'string.rb'
load 'GitLab/gitlab.rb'
load 'Git/git.rb'
load 'Utils/changelog.rb'
load 'menu.rb'

# require 'utils/putdotenv.rb'

# require './lib/gitlab/issue.rb'
# require './lib/gitlab/merge_request.rb'
class SFlow
  extend TtyIntegration
  VERSION = "0.8.0"
  # $TYPE   = ARGV[0]&.encode("UTF-8")
  # $ACTION = ARGV[1]&.encode("UTF-8")

  # branch_name = ARGV[2]&.encode("UTF-8")
  # $PARAM2 = ARGV[3..-1]&.join(' ')&.encode("UTF-8")

  def self.call
    begin
      system('clear')
      Config.init()
      # prompt.ok("GitSflow #{VERSION}")
      box = TTY::Box.frame  align: :center, width: TTY::Screen.width, height: 4, title:  {bottom_right: pastel.cyan("(v#{VERSION})")}  do
        pastel.green("GitSflow")
      end
      print box
      validates()
      Menu.new.principal
    rescue => e
     set_error e

    end
  end
  def self.feature_start external_id_ref, branch_description
    @@bar = bar("Processing ")
    @@bar.start
    2.times { sleep(0.2) ; @@bar.advance }
    title = branch_description || external_id_ref
    issue = GitLab::Issue.new(title: title, labels: ['feature'])
    issue.create
    branch = "#{issue.iid}-feature/#{external_id_ref}"
    self.start(branch, issue)
  end

  def self.bugfix_start external_id_ref, branch_description
    @@bar = bar("Processing ")
    @@bar.start
    2.times { sleep(0.2) ; @@bar.advance }
    title = branch_description || external_id_ref
    issue = GitLab::Issue.new(title: title, labels: ['bugfix'])
    issue.create
    branch = "#{issue.iid}-bugfix/#{external_id_ref}"
    self.start(branch, issue)
  end

  def self.hotfix_start external_id_ref, branch_description
    @@bar = bar("Processing ")
    @@bar.start
    2.times { sleep(0.2) ; @@bar.advance }
    title = branch_description || external_id_ref
    issue = GitLab::Issue.new(title: title, labels: ['hotfix', 'production'])
    issue.create
    branch = "#{issue.iid}-hotfix/#{external_id_ref}"
    self.start(branch, issue, $GIT_BRANCH_MASTER)
  end

  def self.feature_finish branch_name
    self.feature_reintegration branch_name
  end

  def self.feature_reintegration branch_name
    if (!branch_name.match(/\-feature\//))
      raise "This branch is not a feature"
    end
    @@bar = bar("Processing ")
    @@bar.start
    self.reintegration 'feature', branch_name
  end

  def self.bugfix_reintegration branch_name
    if (!branch_name.match(/\-bugfix\//))
      raise "This branch is not a bugfix"
    end
    @@bar = bar("Processing ")
    @@bar.start
    self.reintegration 'bugfix', branch_name
  end

  def self.bugfix_finish branch_name
    self.bugfix_reintegration branch_name
  end

  def self.hotfix_reintegration branch_name
    if (!branch_name.match(/\-hotfix\//))
      raise "This branch is not a hotfix"
    end
    @@bar = bar("Processing ")
    @@bar.start
    self.reintegration 'hotfix', branch_name
  end

  def self.hotfix_finish branch_name
    self.hotfix_reintegration branch_name
  end

  def self.feature_codereview branch_name
    if (!branch_name.match(/\-feature\//))
      raise "This branch is not a feature"
    end
    self.codereview(branch_name)
  end

  def self.bugfix_codereview branch_name
    if (!branch_name.match(/\-bugfix\//))
      raise "This branch is not a bugfix"
    end
    self.codereview(branch_name)
  end

  def self.hotfix_staging branch_name
    if (!branch_name.match(/\-hotfix\//))
      raise "This branch is not a hotfix"
    end
    self.staging branch_name
  end

  def self.bugfix_staging branch_name
    if (!branch_name.match(/\-bugfix\//))
      raise "This branch is not a bugfix"
    end
    self.staging branch_name
  end

  def self.feature_staging branch_name
    if (!branch_name.match(/\-feature\//))
      raise "This branch is not a feature"
    end
    self.staging branch_name
  end

  def self.release_start
    version = branch_name
    if !version
      raise "param 'VERSION' not found"
    end
    issues  = GitLab::Issue.from_list($GITLAB_NEXT_RELEASE_LIST).select{|i| !i.labels.include? 'ready_to_deploy'}
    issues_total = issues.size 
    
    if issues_total == 0
      raise "Not exist ready issues for start release" 
    end

    issues_urgent = issues.select{|i| i.labels.include? 'urgent'}
    issues_urgent_total = issues_urgent.size
    issue_title = "Release version #{version}\n"
    
    issue_release = GitLab::Issue.find_by(title: issue_title) rescue nil
    
    if issue_release
      print "This card was created previously. Do you want to continue using it? (y/n):".yellow.bg_red
      
      print"\n If you choose 'n', a new issue will be created!\n"
      print "\n"
      option = STDIN.gets.chomp
    else
      option = 'n'
    end

    if option == 'n'
      issue_release = GitLab::Issue.new(title: issue_title)
      issue_release.create
    end

    new_labels = []
    changelogs = []

    release_branch = "#{issue_release.iid}-release/#{version}"
    print "Creating release version #{version}\n"

    begin

      Git.delete_branch(release_branch)
      Git.checkout $GIT_BRANCH_DEVELOP
      Git.new_branch release_branch
      
      print "Issue(s) title(s): \n".yellow
      issues.each do |issue|
        print "  -> #{issue.title}\n"
      end
      print "\n"
      
      # if issues_urgent_total > 0
        print "Attention!".yellow.bg_red
        print "\n\nChoose an option for merge:\n".yellow
        print "----------------------------\n".blue
        print "#{"0".ljust(10)} - Only #{issues_urgent_total} hotfix/urgent issues\n".blue if issues_urgent_total > 0
        print "#{"1".ljust(10)} - All #{issues_total} issues\n".blue
        print "----------------------------\n".blue
        print "Choice a number:\n".yellow
        option = STDIN.gets.chomp
      # else
      #   option = "1"
      # end
  
      case option
      when "0"
        print "Issue(s) title(s): \n"
        issues_urgent.each do |issue|
          print "  -> #{issue.title}\n"
        end
        issues_urgent.each do |issue|
          Git.merge(issue.branch, release_branch)
          changelogs << "* ~changelog #{issue.msg_changelog} \n"
          new_labels << 'hotfix'
        end
        issues = issues_urgent
      when "1"
        type = 'other'
        print "Next release has total (#{issues_total}) issues.\n\n".yellow
        print "Issue(s) title(s): \n".yellow
        issues.each do |issue|
          print "  -> #{issue.title}\n"
        end
        issues.each do |issue|
          Git.merge(issue.branch, release_branch)
          changelogs << "* ~changelog #{issue.msg_changelog} \n"
        end
      else
        raise "option invalid!"
      end
      print "Changelog messages:\n\n".yellow
      d_split = $SFLOW_TEMPLATE_RELEASE_DATE_FORMAT.split('/')
      date =  Date.today.strftime("%#{d_split[0]}/%#{d_split[1]}/%#{d_split[2]}")
      version_header =  "#{$SFLOW_TEMPLATE_RELEASE.gsub("{version}", version).gsub("{date}",date)}\n"

      print version_header.blue
      msgs_changelog = []
      changelogs.each do |clog|
        msg_changelog = "#{clog.strip.chomp.gsub('* ~changelog ', '  - ')}\n"
        msgs_changelog << msg_changelog
        print msg_changelog.light_blue
      end
      msgs_changelog << "\n"
      print "\nSetting changelog message in CHANGELOG\n".yellow
      

      system('touch CHANGELOG')

      line = version_header + "  " + msgs_changelog.join('')
      File.write("CHANGELOG",line + File.open('CHANGELOG').read.encode('UTF-8') , mode: "w")

      system('git add CHANGELOG')
      system(%{git commit -m "update CHANGELOG version #{version}"})
      Git.push release_branch

      issue_release.description = "#{changelogs.join("")}\n"
      
      issue_release.labels = ['ready_to_deploy', 'Next Release']
      issue_release.set_default_branch(release_branch)



      print "\n\nTasks list:\n\n".yellow

      tasks = []
      issues.each do |issue|
        if issue.description.match(/(\* \~tasks .*)+/)
          tasks << "* ~tasks #{issue.list_tasks} \n"
        end
      end

      if tasks.size > 0 
        new_labels << 'tasks'

        tasks.each do |task|
          task = "#{task.strip.chomp.gsub('* ~tasks ', '  - ')}\n"
          print task.light_blue
        end
        issue_release.description += "#{tasks.join("")}\n"
      end
      
      issues.each do |issue|
        issue.labels  = (issue.labels + new_labels).uniq
        issue.close
      end
      
      print "\nYou are on branch: #{release_branch}\n".yellow
      print "\nRelease #{version} created with success!\n\n".yellow
      
      issue_release.description += "* #{issues.map{|i| "##{i.iid},"}.join(' ')}"

      issue_release.update

      
    rescue => exception
      Git.delete_branch(release_branch)

      raise exception.message
    end
   
  end

  def self.release_finish 
    version = branch_name
    if !version
      raise "param 'VERSION' not found"
    end
    new_labels = []

    release_branch = "-release/#{version}"
    issue_release = GitLab::Issue.find_by_branch(release_branch)
    
    Git.merge issue_release.branch, $GIT_BRANCH_DEVELOP
    Git.push $GIT_BRANCH_DEVELOP

    type =  issue_release.labels.include?('hotfix') ? 'hotfix' : nil
    mr_master = GitLab::MergeRequest.new(
      source_branch: issue_release.branch,
      target_branch: $GIT_BRANCH_MASTER,
      issue_iid: issue_release.iid,
      title: "Reintegration release #{version}: #{issue_release.branch} into #{$GIT_BRANCH_MASTER}",
      description: "Closes ##{issue_release.iid}",
      type: type
      )
    mr_master.create
     
    # end
    # mr_develop = GitLab::MergeRequest.new(
    #   source_branch: issue_release.branch,
    #   target_branch: $GIT_BRANCH_DEVELOP,
    #   issue_iid: issue_release.iid,
    #   title: "##{issue_release.iid} - #{version} - Reintegration  #{issue_release.branch} into develop",
    #   type: 'hotfix'
    # )
    # mr_develop.create

  

    # remove_labels = [$GITLAB_NEXT_RELEASE_LIST]
    remove_labels = []
    old_labels = issue_release.obj_gitlab["labels"] + ['merge_request']
    old_labels.delete_if{|label| remove_labels.include? label} 
    issue_release.labels = (old_labels + new_labels).uniq
    issue_release.update
    print "\nRelease #{version} finished with success!\n\n".yellow


  end

  def self.push_
    self.push_origin
  end

  def self.push_origin
    branch = !branch_name ?  Git.execute { 'git branch --show-current' } : branch_name
    branch.delete!("\n")
    log_messages = Git.log_last_changes branch
    issue = GitLab::Issue.find_by_branch branch
    Git.push branch 
    if (log_messages != "")
      print "Send messages commit for issue\n".yellow
      issue.add_comment(log_messages)
    end

    remove_labels = $GIT_BRANCHES_STAGING + ['Staging', $GITLAB_NEXT_RELEASE_LIST]
    old_labels = issue.obj_gitlab["labels"]
    old_labels.delete_if{|label| remove_labels.include? label} 

    issue.labels = old_labels +  ['Doing']
    issue.update
    print "Success!\n\n".yellow
  end

  private

  def self.config_
    print "\n\---------- Configuration ---------- \n".light_blue
    print "\nsflow config \nor\ngit sflow config \n\n".light_blue

    print "\In your project create or update file .env with variables below:\n\n"
    print "GITLAB_PROJECT_ID=\n".pink
    print "GITLAB_TOKEN=\n".pink
    print "GITLAB_URL_API=\n".pink
    print "GITLAB_EMAIL=\n".pink
    print "GITLAB_LISTS=To Do,Doing,Next Release,Staging\n".pink
    print "GITLAB_NEXT_RELEASE_LIST=Next Release\n".pink
    print "GIT_BRANCH_MASTER=master\n".pink
    print "GIT_BRANCH_DEVELOP=develop\n".pink
    print "GIT_BRANCHES_STAGING=staging_1,staging_2\n".pink
    print "SFLOW_TEMPLATE_RELEASE=Version {version} - {date}\n".pink
    print "SFLOW_TEMPLATE_RELEASE_DATE_FORMAT=d/m/Y\n".pink
    
  end

  def self.set_error(e)
    print "\n\n"
    print TTY::Box.error(e.message, border: :light)
    
    # print "Error!".yellow.bg_red
    # print "\n"
    # print "#{e.message}".yellow.bg_red
    # print "\n\n"
    # e.backtrace.each { |line| print "#{line}\n"  }
    
    # print "\n\n"
  end

  def self.validates
    @@bar = bar
    6.times {
      sleep(0.2)
      @@bar.advance
    }
    if !$GITLAB_PROJECT_ID || !$GITLAB_TOKEN || !$GITLAB_URL_API ||
      !$GIT_BRANCH_MASTER || !$GIT_BRANCH_DEVELOP  || !$GITLAB_LISTS || !$GITLAB_NEXT_RELEASE_LIST
      @@bar.stop
      Menu.new.setup_variables()
      @@bar.finish
    end

    begin
      branchs_validations = $GIT_BRANCHES_STAGING + [$GIT_BRANCH_MASTER, $GIT_BRANCH_DEVELOP]
      Git.exist_branch?(branchs_validations.join(' '))
    rescue => e
      @@bar.stop
      raise "You need to create branches #{branchs_validations.join(', ')}"
      # Menu.new.setup_variables()
    end
    2.times {
      sleep(0.2)
      @@bar.advance
    }

    # Git.exist_branch?(branchs_validations.join(' ')) rescue raise "You need to create branches #{branchs_validations.join(', ')}"

    2.times {
      sleep(0.2)
      @@bar.advance
    }
    GitLab::Issue.ping
    @@bar.finish

  end


  def self.reintegration type = "feature", branch_name
    
    # Git.fetch ref_branch
    # Git.checkout ref_branch
    # Git.pull ref_branch
    source_branch = branch_name
    issue = GitLab::Issue.find_by_branch(source_branch)
    2.times { sleep(0.2) ; @@bar.advance }
    # Setting Changelog
    # print "Title: #{issue.title}\n\n"
    # print "CHANGELOG message:\n--> ".yellow
    message_changelog = prompt.ask("Set message CHANGELOG:", require: true, default: issue.title)
    # message_changelog = STDIN.gets.chomp.to_s.encode('UTF-8')
    # print "\n ok!\n\n".green
    new_labels = []
    if (type == 'hotfix')
      !source_branch.match('hotfix') rescue raise "invalid branch!"
      new_labels << 'hotfix'
      new_labels << 'urgent'
    else
      (!source_branch.match('feature') && !source_branch.match('bugfix'))  rescue  raise "invalid branch!"
    end
    remove_labels = $GIT_BRANCHES_STAGING + $GITLAB_LISTS + ['Staging']
    new_labels << 'changelog'
    new_labels << $GITLAB_NEXT_RELEASE_LIST
    old_labels = issue.obj_gitlab["labels"]
    old_labels.delete_if{|label| remove_labels.include? label} 
    issue.labels = (old_labels + new_labels).uniq
    issue.description.gsub!(/\* \~changelog .*\n?/,'')
    issue.description = "#{issue.description} \n* ~changelog #{message_changelog}"

    # Setting Tasks
    tasks = prompt.ask("Set tasks list (optional):")

    issue.update
    success("#{branch_name} was finished and transferred to #{$GITLAB_NEXT_RELEASE_LIST} with sucesss!")
  end

  def self.start branch, issue, ref_branch = $GIT_BRANCH_DEVELOP
    2.times { sleep(0.2) ; @@bar.advance }
    Git.checkout ref_branch
    description = "* ~default_branch #{branch}"
    issue.description = description
    issue.update
    2.times { sleep(0.2) ; @@bar.advance }
    Git.new_branch branch
    Git.push branch

    @@bar.finish
    prompt.say(pastel.cyan("You are on branch: #{branch}"))
    success("Issue created with success!\nURL: #{issue.web_url}")

    # print "\nYou are on branch: #{branch}\n\n".yellow
  end

  def self.codereview branch_name
    Git.checkout $GIT_BRANCH_DEVELOP
    source_branch = branch_name
    issue = GitLab::Issue.find_by_branch(source_branch)
    # issue.move
    mr = GitLab::MergeRequest.new(
      source_branch: source_branch,
      target_branch: $GIT_BRANCH_DEVELOP,
      issue_iid: issue.iid
      )
    mr.create_code_review
    issue.labels = (issue.obj_gitlab["labels"] + ['code_review']).uniq
    issue.update
  end

  def self.staging branch_name
    branch = branch_name
    issue = GitLab::Issue.find_by_branch(branch)
    prompt.say(pastel.cyan("\nLet's go!"))
    target_branch = prompt.select("\nChoose target branch", $GIT_BRANCHES_STAGING ,symbols: { marker: ">" }, filter: true)

    options = []
    options << {name: 'Clean and Merge', value: :clear }
    options << {name: 'Only Merge', value: :only_merge }
    option_merge = prompt.select("\nChoose mode", options ,symbols: { marker: ">" }, filter: true)

    if option_merge == :clear
      issues_staging  = GitLab::Issue.from_list(target_branch).select{|i| i.branch != branch}
      issues_staging.each do |i|
        i.labels.delete(target_branch)
        i.labels.delete('Staging')
        i.labels.push('Doing')
        i.update
      end
      Git.reset_hard branch, target_branch
      Git.push_force target_branch
    elsif option_merge == :only_merge
      Git.reset_hard target_branch, target_branch
      Git.merge branch, target_branch
      Git.push target_branch
    else
      raise 'Wrong choice'
    end
    
    new_labels = [target_branch, 'Staging']
    remove_labels =  $GITLAB_LISTS
    old_labels = issue.obj_gitlab["labels"]
    old_labels.delete_if{|label| remove_labels.include? label} 
    issue.labels = (old_labels + new_labels).uniq
    issue.update

    self.codereview branch_name
    Git.checkout(branch)
  end
end

