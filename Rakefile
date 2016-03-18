require "bundler/gem_tasks"
require "rake/testtask"
require "reevoocop/rake_task"

ReevooCop::RakeTask.new(:reevoocop)

Rake::TestTask.new(:tests) do |t|
  t.test_files = Dir["test/**/test_*.rb"]
end

task default: :test
task build: :test
task tests: :reevoocop

namespace :docker do
  task :test do
    sh "docker build ."
  end
end

task :test do
  if system("which journalctl")
    Rake::Task["tests"].invoke
  else
    Rake::Task["docker:test"].invoke
  end
end
