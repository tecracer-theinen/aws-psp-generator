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

require 'bump/tasks'
%w[set pre file current].each { |task| Rake::Task["bump:#{task}"].clear }
Bump.changelog = :editor
Bump.tag_by_default = true

namespace :lint do
  desc 'Linting for all markdown files'
  task :markdown do
    require 'mdl'

    MarkdownLint.run(%w[--verbose README.md CHANGELOG.md])
  end
end
