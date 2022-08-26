require "bundler/gem_tasks"

Rake::Task["release"].clear

# We run tests by default
task :default => :test
#task :gem => :build

task :build do
  sh <<~EOS, { verbose: false }
    rubocop --only Lint/Syntax --fail-fast --format quiet
  EOS
end
