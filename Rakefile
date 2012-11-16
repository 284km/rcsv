#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rake/extensiontask"
require 'rake/testtask'

Rake::ExtensionTask.new('rcsv') do |ext|
  ext.lib_dir = 'lib/rcsv'
end

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Recompile native code"
task :recompile => [:clobber, :compile] # clean build

desc "Recompile native code and run tests"
task :default => [:recompile, :test] # clean testing FTW
