#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

# randomwordgenerator.rb
#
# Copyright © 2011-2015 Lorin Ricker <lorin@rickernet.us>
# Version 0.4, 10/15/2014
#
# This program is free software, under the terms and conditions of the
# GNU General Public License published by the Free Software Foundation.
# See the file 'gpl' distributed within this project directory tree.

# Generate a random word (password) based on the pattern "pat" parameter

# Examples:
#   randomWord                     => 'Hoglin'
#   randomWord                     => 'Gupbez'
#   randomWord( 'Cvcc*vCvvc' )     => 'Wurp^iZuuw'
#   randomWord( 'V*c*vCv*c' )      => 'A#d%aZe&p'

def randomWord( pat = 'Cvccvc' )
  letters = { ?V => 'AEIOU',
              ?v => 'aeiou',
              ?C => 'BCDFGHJKLMNPRSTVWXYZ',
              ?c => 'bcdfghjklmnprstvwxyz',
              ?* => '~!@#$%^&*<>?/' }
  word = ''
  pat.bytes do |x|
    source = letters[x.chr]
    word << source[rand(source.length)].chr
  end
  return word
end  # randomWord

# Main -- test driver:
if $0 == __FILE__ then
  puts "  \"#{randomWord}\""
  puts "  \"#{randomWord( 'Cvcc*vcvvc' )}\""
  puts "  \"#{randomWord( '****' )}\""
end
