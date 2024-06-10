begin
  require 'dotenv'
  Dotenv.load(File.join( Dir.pwd, ".env"))
rescue LoadError
  # Gem loads as it should
end

require 'tty_integration.rb'
module Config
  extend TtyIntegration
  def self.init
    project_name = cmd.run!("git remote -v | grep origin | head -n1 | awk '{print $2}' | sed -e 's,.*:\(.*/\)\?,,' -e 's/\.git$//'").out
    file = "#{Dir.home}/.config/gitsflow/#{project_name.gsub("\n","")}/config.yml"
    config = TTY::Config.new
    config.filename = file

    begin
      result = config.read(file).transform_keys(&:to_sym)   
      $GITLAB_PROJECT_ID = result[:GITLAB_PROJECT_ID]
      $GITLAB_TOKEN = result[:GITLAB_TOKEN]
      $GITLAB_URL_API = result[:GITLAB_URL_API]
      $GITLAB_EMAIL = result[:GITLAB_EMAIL]
      $GITLAB_LISTS = result[:GITLAB_LISTS].split(',')
      $GITLAB_NEXT_RELEASE_LIST = result[:GITLAB_NEXT_RELEASE_LIST]
      $GIT_BRANCH_MASTER = result[:GIT_BRANCH_MASTER]
      $GIT_BRANCH_DEVELOP = result[:GIT_BRANCH_DEVELOP]
      $GIT_BRANCHES_STAGING= result[:GIT_BRANCHES_STAGING].split(',')
      $SFLOW_TEMPLATE_RELEASE= result[:SFLOW_TEMPLATE_RELEASE]
      $SFLOW_TEMPLATE_RELEASE_DATE_FORMAT= result[:SFLOW_TEMPLATE_RELEASE_DATE_FORMAT]

    rescue => e

    end
  end
end
