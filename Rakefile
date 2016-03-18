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
  task test: [:ubuntu, :centos]

  task :ubuntu do
    FileUtils.cp("test/docker/Dockerfile.ubuntu", "Dockerfile")
    sh "docker build ."
    FileUtils.rm("Dockerfile")
  end

  task :centos do
    FileUtils.cp("test/docker/Dockerfile.centos", "Dockerfile")
    sh "docker build ."
    FileUtils.rm("Dockerfile")
  end
end
