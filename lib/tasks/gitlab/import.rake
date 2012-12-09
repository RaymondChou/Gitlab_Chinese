namespace :gitlab do
  namespace :import do
    # How to use:
    #
    #  1. copy your bare repos under git base_path
    #  2. run bundle exec rake gitlab:import:repos RAILS_ENV=production
    #
    # Notes:
    #  * project owner will be a first admin
    #  * existing projects will be skipped
    #
    desc "GITLAB | Import bare repositories from git_host -> base_path into GitLab project instance"
    task :repos => :environment do

      git_base_path = Gitlab.config.git_base_path
      repos_to_import = Dir.glob(git_base_path + '/*')

      repos_to_import.each do |repo_path|
        repo_name = File.basename repo_path

        # skip gitolite admin
        next if repo_name == 'gitolite-admin.git'

        path = repo_name.sub(/\.git$/, '')

        project = Project.find_by_path(path)

        puts "Processing #{repo_name}".yellow

        if project
          puts " * #{project.name} (#{repo_name}) exists"
        else
          user = User.admins.first

          project_params = {
            :name => path,
            :code => path,
            :path => path,
          }

          project = Project.create_by_user(project_params, user)

          if project.valid?
            puts " * Created #{project.name} (#{repo_name})".green
          else
            puts " * Failed trying to create #{project.name} (#{repo_name})".red
          end
        end
      end

      puts "Done!".green
    end
  end
end
