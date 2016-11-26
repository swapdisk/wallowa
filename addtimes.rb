#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

# addtimes.rb
#
# Copyright © 2016 Lorin Ricker <lorin@rickernet.us>
# Version info: see PROGID below...
#
# This program is free software, under the terms and conditions of the
# GNU General Public License published by the Free Software Foundation.
# See the file 'gpl' distributed within this project directory tree.
#

PROGNAME = File.basename $0
  PROGID = "#{PROGNAME} v1.0 (11/26/2016)"
  AUTHOR = "Lorin Ricker, Elbert, Colorado, USA"

DBGLVL0 = 0
DBGLVL1 = 1
DBGLVL2 = 2  ######################################################
DBGLVL3 = 3  # <-- reserved for binding.pry &/or pry-{byebug|nav} #
             ######################################################
# -----

require 'optparse'
require 'pp'
require_relative 'lib/TimeInterval'
require_relative 'lib/GetPrompted'
require_relative 'lib/ANSIseq'

# ==========

# === Main ===
options = { :operator => :add,
            :start    => nil,
            :prompt   => false,
            :noop     => false,
            :verbose  => false,
            :debug    => DBGLVL0,
            :about    => false
          }

optparse = OptionParser.new { |opts|
  opts.on( "-o", "--operator=OP",
           /add|subtract|plus|minus/,
           "'add' (default, 'plus') or 'subtract' ('minus')" ) do |val|
    options[:operator] = val.downcase.to_sym
    options[:operator] = :add      if options[:operator] == :plus
    options[:operator] = :subtract if options[:operator] == :minus
  end  # -o --operator=OP
  opts.on( "-s", "--start=TIMEINT", "Starting time interval value;",
                 "required for --operator=minus|subtract" ) do |val|
    options[:start] = val
  end  # -s --start
  opts.on( "-p", "--prompt", "Prompt mode; can be used/combined with",
                             "arguments (timeints) on com-line" ) do |val|
    options[:prompt] = true
  end  # -p --prompt
  opts.separator ""
  # -n --dryrun not implemented, not needed for this program:
  # opts.on( "-n", "--noop", "--dryrun", "--test",
  #          "Dry-run (test & display, no-op) mode" ) do |val|
  #   options[:noop]  = true
  #   options[:verbose] = true  # Dry-run implies verbose...
  # end  # -n --noop
  # --- Verbose option ---
  opts.on( "-v", "--verbose", "--log", "Verbose mode" ) do |val|
    options[:verbose] = true
  end  # -v --verbose
  # --- Debug option ---
  opts.on( "-d", "--debug", "=DebugLevel", Integer,
           "Show debug information (levels: 1, 2 or 3)",
           "  1 - enables basic debugging information",
           "  2 - enables advanced debugging information",
           "  3 - enables (starts) pry-byebug debugger" ) do |val|
    options[:debug] = val.to_i
  end  # -d --debug
  # --- About option ---
  opts.on_tail( "-a", "--about", "Display program info" ) do |val|
    $stdout.puts "#{PROGID}"
    $stdout.puts "#{AUTHOR}"
    options[:about] = true
    exit true
  end  # -a --about
  # --- Set the banner & Help option ---
  opts.banner = "  Adds (or subtracts) time intervals or durations." +
                "\n\n  Usage: #{PROGNAME} [options] timeint1 [timeint2...]" +
                "\n\n  where each timeintN is a time interval or duration." +
                "\n\n  A timeint value is entered as:" +
                "\n\n    M            - Minutes: an integer (no punctuation)" +
                "\n    MM:SS        - Minutes and Seconds" +
                "\n    HH:MM:SS     - Hours, Minutes and Seconds" +
                "\n    D HH:MM[:SS] - Days, Hours, Minutes and (optional) Seconds" +
                "\n\n  Note: to facilitate timeint entry from the Numeric Keypad," +
                "\n  a period or dot '.' can substitute for a colon ':', and" +
                "\n  a dash '-' can substitute for the space ' ' after Days." +
                "\n\n  Examples: 5 (five minutes); 1:30 (a minute and a half);" +
                "\n            2:20:02 (two hours, twenty minutes and two seconds);" +
                "\n            3 3:30:03 (3 days, 3 hours, thirty minutes and three seconds);" +
                "\n            or equivalents: 1.30; 2.20.02; 3-3.30.03;; or even 3-3:30.03" +
                "\n\n"
  opts.on_tail( "-?", "-h", "--help", "Display this help text" ) do |val|
    $stdout.puts opts
    # $stdout.puts "«+»Additional Text«+»"
    options[:help] = true
    exit true
  end  # -? --help
}.parse!  # leave residue-args in ARGV

###############################
if options[:debug] >= DBGLVL3 #
  require 'pry'               #
  binding.pry                 #
end                           #
###############################

if ( options[:operator] == :subtract ) && ( ! options[:start] )
  puts "%#{PROGNAME}-e-required, --start=TIMEINT required for subtract operations"
  exit false
end

# accumlates seconds, t+o be displayed as interval "d hh:mm:ss"
accint = TimeInterval.new( opts = options )
pstr = "  0 00:00:00"

accint.accumulate( options[:start], :add ) if options[:start]
pstr = accint.to_s

if ARGV[0]
  # Add all given args on command-line, even if prompt-mode is requested...
  ARGV.each do | arg |
    accint.accumulate( arg, options[:operator] )
    pstr = accint.to_s
  end
end
if options[:prompt]
  # ...Prompt user for values, show running-tape of accumulated/calc'd time
  # display current interval as prompt> -- get user's input, no default answer:
  while pstr = getprompted( "#{pstr} > ", "", true )
    break if pstr == ""
    accint.accumulate( pstr, options[:operator] )
    pstr = accint.to_s
  end  # while
end

pstr = $stdout.tty? ? accint.to_s.trim.bold.underline : accint.to_s
puts "\nAccumulated interval/duration: #{ pstr }\n"

exit true
