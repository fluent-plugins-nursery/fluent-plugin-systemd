require "bundler/gem_tasks"
require "rake/testtask"
require "reevoocop/rake_task"
require "fileutils"

ReevooCop::RakeTask.new(:reevoocop)

Rake::TestTask.new(:tests) do |t|
  t.test_files = Dir["test/**/test_*.rb"]
end

task default: :test
task build: :test
task tests: :reevoocop

task test: "docker:test"
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
