require "bundler/gem_tasks"
require "rake/testtask"
require "reevoocop/rake_task"
require "fileutils"

ReevooCop::RakeTask.new(:reevoocop)

Rake::TestTask.new(:test) do |t|
  t.test_files = Dir["test/**/test_*.rb"]
end

task default: "docker:test"
task build: "docker:test"
task test: :reevoocop

namespace :docker do
  distros = [:ubuntu, :"tdagent-ubuntu", :centos, :"tdagent-centos"]
  task test: distros

  distros.each do |distro|
    task distro do
      puts "testing on #{distro}"
      begin
        FileUtils.cp("test/docker/Dockerfile.#{distro}", "Dockerfile")
        sh "docker build ."
      ensure
        FileUtils.rm("Dockerfile")
      end
    end
  end
end
