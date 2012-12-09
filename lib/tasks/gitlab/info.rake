namespace :gitlab do
  namespace :env do
    desc "GITLAB | Show information about GitLab and its environment"
    task info: :environment  do

      # check which OS is running
      os_name = run("lsb_release -irs")
      os_name ||= if File.readable?('/etc/system-release')
                    File.read('/etc/system-release')
                  end
      os_name ||= if File.readable?('/etc/debian_version')
                    debian_version = File.read('/etc/debian_version')
                    "Debian #{debian_version}"
                  end
      os_name.squish!

      # check if there is an RVM environment
      rvm_version = run_and_match("rvm --version", /[\d\.]+/).try(:to_s)
      # check Gem version
      gem_version = run("gem --version")
      # check Bundler version
      bunder_version = run_and_match("bundle --version", /[\d\.]+/).try(:to_s)
      # check Bundler version
      rake_version = run_and_match("rake --version", /[\d\.]+/).try(:to_s)

      puts ""
      puts "System information".yellow
      puts "System:\t\t#{os_name || "unknown".red}"
      puts "Current User:\t#{`whoami`}"
      puts "Using RVM:\t#{rvm_version.present? ? "yes".green : "no"}"
      puts "RVM Version:\t#{rvm_version}" if rvm_version.present?
      puts "Ruby Version:\t#{ENV['RUBY_VERSION'] || "unknown".red}"
      puts "Gem Version:\t#{gem_version || "unknown".red}"
      puts "Bundler Version:#{bunder_version || "unknown".red}"
      puts "Rake Version:\t#{rake_version || "unknown".red}"


      # check database adapter
      database_adapter = ActiveRecord::Base.connection.adapter_name.downcase

      project = Project.new(path: "some-project")
      project.path = "some-project"
      # construct clone URLs
      http_clone_url = project.http_url_to_repo
      ssh_clone_url  = project.ssh_url_to_repo

      puts ""
      puts "GitLab information".yellow
      puts "Version:\t#{Gitlab::Version}"
      puts "Revision:\t#{Gitlab::Revision}"
      puts "Directory:\t#{Rails.root}"
      puts "DB Adapter:\t#{database_adapter}"
      puts "URL:\t\t#{Gitlab.config.url}"
      puts "HTTP Clone URL:\t#{http_clone_url}"
      puts "SSH Clone URL:\t#{ssh_clone_url}"
      puts "Using LDAP:\t#{Gitlab.config.ldap_enabled? ? "yes".green : "no"}"
      puts "Using Omniauth:\t#{Gitlab.config.omniauth_enabled? ? "yes".green : "no"}"
      puts "Omniauth Providers:\t#{Gitlab.config.omniauth_providers}" if Gitlab.config.omniauth_enabled?



      # check Gitolite version
      gitolite_version_file = "#{Gitlab.config.git_base_path}/../gitolite/src/VERSION"
      if File.exists?(gitolite_version_file) && File.readable?(gitolite_version_file)
        gitolite_version = File.read(gitolite_version_file)
      end

      puts ""
      puts "Gitolite information".yellow
      puts "Version:\t#{gitolite_version || "unknown".red}"
      puts "Admin URI:\t#{Gitlab.config.gitolite_admin_uri}"
      puts "Admin Key:\t#{Gitlab.config.gitolite_admin_key}"
      puts "Repositories:\t#{Gitlab.config.git_base_path}"
      puts "Hooks:\t\t#{Gitlab.config.git_hooks_path}"
      puts "Git:\t\t#{Gitlab.config.git.path}"

    end


    # Helper methods

    # Runs the given command and matches the output agains the given RegExp
    def run_and_match(command, regexp)
      run(command).try(:match, regexp)
    end

    # Runs the given command
    #
    # Returns nil if the command was not found
    # Returns the output of the command otherwise
    def run(command)
      unless `#{command} 2>/dev/null`.blank?
        `#{command}`
      end
    end
  end
end
