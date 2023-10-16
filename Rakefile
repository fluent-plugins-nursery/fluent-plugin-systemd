# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'
require 'fileutils'

RuboCop::RakeTask.new(:rubocop)

Rake::TestTask.new(:test) do |t|
  t.test_files = Dir['test/**/test_*.rb']
end

task default: 'docker:test'
task build: 'docker:test'
task default: :rubocop

namespace :docker do
  distros = %i[ubuntu tdagent-ubuntu tdagent-almalinux]
  task test: distros

  distros.each do |distro|
    task distro do
      puts "testing on #{distro}"
      sh "sudo docker build . -f test/docker/Dockerfile.#{distro}"
    end
  end
end
