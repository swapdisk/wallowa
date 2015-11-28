#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

# purgekernel.rb
#
# Copyright © 2015 Lorin Ricker <Lorin@RickerNet.us>
# Version info: see PROGID below...
#
# This program is free software, under the terms and conditions of the
# GNU General Public License published by the Free Software Foundation.
# See the file 'gpl' distributed within this project directory tree.

# purgekernel supports the automated (user-driven) removal of old Linux kernel
# packages, using a command shell to execute 'apt-get purge linux-*' for both
# kernel images and kernel headers ...
# See "$dlb/Linux/HowTos/HowTo - Remove old Linux kernel packages.txt"

# -----

PROGNAME = File.basename $0
  PROGID = "#{PROGNAME} v0.1 (11/27/2015)"
  AUTHOR = "Lorin Ricker, Elbert, Colorado, USA"

# -----

MAGICSTR = '»·«'  # literally, this replacement string
LOLIMIT  =    0
HILIMIT  = 1000

DBGLVL0 = 0
DBGLVL1 = 1
DBGLVL2 = 2  ######################################################
DBGLVL3 = 3  # <-- reserved for binding.pry &/or pry-{byebug|nav} #
             ######################################################
# ==========

require 'optparse'
require 'pp'
require_relative 'lib/AskPrompted'
require_relative 'lib/TermChar'
require_relative 'lib/ANSIseq'

# ==========

# Build the 'purgethese' array of linux kernel packages to purge:
# def build_purge( pkg )
#   puts "...would purge '#{pkg}'!"
# end  # build_purge

# ==========

options = { :show        => nil,
            :lessthan    => nil,
            :greaterthan => nil,
            :confirm     => nil,
            :logfile     => "./" + PROGNAME + "_" +
                            Time.now.strftime("%Y-%m-%d_%H%M") + ".log",
            :noop        => true,  # nil,
            :verbose     => false,
            :debug       => DBGLVL0,
            :about       => false
          }

ARGV[0] = '--help' if ARGV.size == 0  # force help if naked command-line

optparse = OptionParser.new { |opts|
  opts.on( "-s", "--show", "--list",
           "List currently installed Linux kernel packages" ) do |val|
    options[:show] = val
    # If we're showing, we're not doing anything else...
    options[:lessthan] = options[:greaterthan] = options[:confirm] = nil
  end  # -s --show
  opts.on( "-g", "--greaterthan=LoValue", Integer,
           "Purge dash-numbers #{'greater than'.bold} LoValue ..." ) do |val|
    options[:greaterthan] = val.to_i
  end  # -g --greaterthan
  opts.on( "-l", "--lessthan=HiValue", Integer,
           "  ... and/or #{'less than'.bold} HiValue" ) do |val|
    options[:lessthan] = val.to_i
  end  # -l --lessthan
  opts.on( "-i", "--confirm", "--interactive",
           "Interactive/confirm mode" ) do |val|
    options[:confirm] = val
  end  # -i --confirm -- interactive
  opts.on( "-e", "--logfile", "--errlog",
           "Log-file (default: '#{options[:logfile]}')" ) do |val|
    options[:logfile] = val
  end  # -e --logfile --errlog
  opts.on( "-n", "--dryrun", "Test (rehearse) the kernel package purge" ) do |val|
    options[:noop] = true
  end  # -n --dryrun
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
  opts.banner = "\n  Usage: #{PROGNAME} [options] [ kernel-ident ... ]" +
                "\n\n    where kernel-ident is a list of one or more" +
                "\n    #{'kernel install packages to purge'.underline}.\n\n"
  opts.on_tail( "-?", "-h", "--help", "Display this help text" ) do |val|
    $stdout.puts opts
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

options[:verbose] = options[:debug] >= DBGLVL1

# Each uninitialized hash-key returns an empty array --
kernelpackages    = Hash.new { |k,v| k[v] = [] }
kernels2purge     = Hash.new { |k,v| k[v] = [] }
confirmedpackages = Array.new
purgepackages     = Array.new

# See man dpkg-query (watch out for automatic
# field-width truncations under column "Name"!) --
cmd = "dpkg-query --show --showformat='${Status} ${Package}\n' \"linux*\""
pat = /^install\ ok\ installed\            # only Install-Installed packages
       (?<pckg>                            # full package name
       (?<pfix>linux-(image|headers)-)     # only linux* (kernel) packages
       (?<vers>\d+\.\d+\.\d+)              # MM.mm.rev version spec
       -(?<dash>\d+)                       # -dash spec
           (\.\d+)?                        # don't care: .XX
       (?<sfix>(-\w+)?)                    # "-generic" or empty
       )
      /x

prefix = suffix = kversion = ''

%x{ #{cmd} }.lines do | line |
  puts ">> #{line}" if options[:verbose]
  m = pat.match( line )
  if m
    prefix   = m[:pfix] if prefix   != m[:pfix]
    kversion = m[:vers] if kversion != m[:vers]
    suffix   = m[:sfix] if suffix   != m[:sfix]
    package  = "#{prefix}#{kversion}-#{MAGICSTR}#{suffix}"
    if ARGV.empty?
      kernelpackages[ package ] << m[:dash]
    else
      ARGV.each { | arg | kernelpackages[package] << arg } if kernelpackages[package].empty?
    end
  end
end

$stdout.puts "kernelpackages -- #{kernelpackages}" if options[:debug] >= DBGLVL2

# Show/list packages in a nice sorted order, then just exit...
if options[:show]
  puts "Currently installed Linux Kernel Packages".bold.underline
  kernelpackages.each do | package, versions |
    versions.sort! { | a, b | b <=> a }
    versions.each do | vrs |
      p = package.gsub( /#{MAGICSTR}/, vrs.bold )
      puts "  #{p}"
    end
  end
  exit true
end

# Create a comparison range: options[:greaterthan]...options[:lessthan]
# and substituting LOLIMIT and/or HILIMIT if either or both of these
# options are not specified; thus, the defaulted range LOLIMIT...HILIMIT
# means "all versions" --
hidash = options[:lessthan]    || HILIMIT
lodash = options[:greaterthan] || LOLIMIT
# This range comparison must *exclude* >both< of the end-points!
lodash += 1 if lodash > LOLIMIT
dashrange = Range.new( lodash, hidash, true )  # exclusive: ...

kernelpackages.each do | package, versions |
  versions.each do | vrs |
    kernels2purge[ package ] << vrs if dashrange.include?( vrs.to_i )
  end
end

$stdout.puts "kernels2purge -- #{kernels2purge}" if options[:debug] >= DBGLVL2

# Now that the range of -dash versions is limited to just those
# in the lodash...hidash range, run an interactive check if
# the user asked for it with --confirm (etc) --

kernels2purge.each do | package, versions |
  if options[:confirm]
    # Use the confirmed packages (only) --
    versions.each do | vrs |
      prompt = "Purge package " + package.gsub( /#{MAGICSTR}/, vrs.bold )
      confirmedpackages << vrs if askprompted( prompt, "No" )
    end
  else
    # Use the full array of found packages --
    confirmedpackages = versions
  end
  purgepackages << package.gsub( /#{MAGICSTR}/, "{#{confirmedpackages.join(',')}}" )
end

$stdout.puts "purgepackages -- #{purgepackages}" if options[:debug] >= DBGLVL2

purgepackages.each do | package |
  noop = options[:noop] ? " --dry-run" : ""
  cmd = "apt-get purge --yes#{noop} #{package}"
  $stdout.puts "\n\ncmd.bold\n" if options[:verbose]
  %x{ cmd }.each do | line |
    if options[:verbose]
      $stdout.puts "  >> #{line}"
    else
      # case line   # output only selected lines...
      # when /^.../ then $stdout.puts "  >> #{line}"
      # end
    end
    $stderr.puts line   # always echo all lines to stderr-file
  end
end

exit true
