#!/usr/bin/env ruby
# frozen_string_literal: true

unless ARGV[0]
  puts 'Usage: new_post.rb post_name'
  exit!
end

emptycontent = <<~CONTENT
  
  title: #{ARGV[0]}
  date: #{Time.now.strftime('%Y-%m-%d-%H:%M:%S')}
  
  ---
  
  ##{ARGV[0]}
  
CONTENT

File.write('blog/' + [Time.now.strftime('%Y-%m-%d-%H%M%S'), ARGV[0]].join('_') + '.md', emptycontent)
