#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

# bru.rb
#
# Copyright © 2012-14 Lorin Ricker <Lorin@RickerNet.us>
# Version info: see PROGID below...
#
# This program is free software, under the terms and conditions of the
# GNU General Public License published by the Free Software Foundation.
# See the file 'gpl' distributed within this project directory tree.

# -----

PROGNAME = File.basename $0
  PROGID = "#{PROGNAME} v1.05 (11/09/2014)"
  AUTHOR = "Lorin Ricker, Castle Rock, Colorado, USA"

   CONFIGDIR = File.join( ENV['HOME'], ".config", PROGNAME )
  CONFIGFILE = File.join( CONFIGDIR, "#{PROGNAME}.yaml.rc" )

  DEFEXCLFILE   = File.join( CONFIGDIR, 'common_rsync.excl' )
  DEFSOURCETREE = File.join( '/home', ENV['USER'], "" )  # ensure a trailing '/'
  DEFBACKUPTREE = File.join( '/media', ENV['USER'], DEFSOURCETREE )

DBGLVL0 = 0
DBGLVL1 = 1
DBGLVL2 = 2
DBGLVL3 = 3

# -----

# bru provides a command line driver for routine rsync backup and restore
# operations on a known, YAML-configured /home/USER/... directory tree.
# Having written similarly-purposed scripts in bash, this Ruby implementation
# provides logical and comprehensible simplicity and maintainability, plus
# considerably better error-checking, command-line interfacing, robustness
# and recoverability.

# === For command-line arguments & options parsing: ===
require 'optparse'        # See "Pickaxe v1.9", p. 776
require 'fileutils'
require 'pp'
require_relative 'lib/StringEnhancements'
require_relative 'lib/FileEnhancements'
require_relative 'lib/ANSIseq'
require_relative 'lib/AskPrompted'

# ==========

def config_save( opt )
  # opt is a local copy of options, so we can patch a few
  # values without disrupting the original/global hash --
  opt[:about]     = false
  opt[:debug]     = DBGLVL0
  opt[:recover]   = false
  opt[:noop]      = false
  opt[:sudo]      = ""
  opt[:update]    = false
  opt[:verbose]   = false
  AppConfig.configuration_yaml( CONFIGFILE, opt, true )  # force the save/update
end  # config_save

def excludespec( optfile, deffile, opttext = "" )
  fil  = optfile ? File.absolute_path( optfile ) : File.absolute_path( deffile )
  fil += '/' if File.directory?( fil ) && fil[-1] != '/'
  opt  = opttext + fil
  fil  = "«not found»" if not File.exists?( fil )
  return [ fil, opt ]
end  # excludespec

def dirspec( optdir, defdir )
  dir  = optdir ? File.absolute_path( optdir ) : File.absolute_path( defdir )
  dir += '/' if File.directory?( dir ) && dir[-1] != '/'
  return dir
end  # dirspec

def dir_error( op, dir )
  $stderr.puts "%#{PROGNAME}-e-fnf, #{op} Directory Tree not found: #{dir}"
  exit false
end  # dir_error

def make_tree( op, dir, options )
  if options[:verbose]
    answer = askprompted( "#{op} Directory Tree does not exist; create it" )
    dir_error( op, dir ) if not answer  # "No"? -- error-msg and exit
  end
  pp dir
  pp options
  FileUtils.mkdir_p( dir, :mode => 0700,
                     :noop => options[:noop], :verbose => options[:verbose] )
end  # make_tree

# ==========

options = {
            :sourcetree => nil,
            :backuptree => nil,
            :exclude    => "none",
            :itemize    => false,
            :about      => false,
            :debug      => DBGLVL0,
            :recover    => false,
            :noop       => false,
            :sudo       => "",
            :update  => false,
            :verbose    => false
          }

options.merge!( AppConfig.configuration_yaml( CONFIGFILE, options ) )

optparse = OptionParser.new { |opts|
  opts.on( "-s", "--sourcetree", "=SourceDir", String,
           "Source directory tree" ) do |val|
    options[:sourcetree] = val
  end  # -s --sourcetree
  opts.on( "-b", "--backuptree", "=BackupDir", String,
           "(optional) Backup directory tree - If specified, this",
           "value overrides any other backup directory given on",
           "the command line; this value will be saved in the",
           "configuration file if --update is also specified" ) do |val|
    options[:backuptree] = val
  end  # -b --sourcetree
  opts.on( "-e", "--exclude", "=ExcludeFile", String,
           "Exclude-file containing files (patterns) to omit",
           "from this backup; if there is no exclude-file,",
           "specify as '--exclude-file=none'" ) do |val|
    options[:exclude] = val || "none"
  end  # -e --exclude
    opts.on( "-i", "--[no-]itemize",
           "Itemize changes (output) during file transfer" ) do |val|
    options[:itemize] = val
  end  # -i --itemize
  opts.separator ""
  opts.separator "    The options below are always saved in the configuration file"
  opts.separator "    in their 'off' or 'default' state:"
  opts.on( "-r", "--recover", "--restore",
           "Recover (restore) the SourceDirectory from the BackupDir" ) do |val|
    options[:recover] = true
  end  # -r --recover
  opts.on( "-S", "--sudo",
           "Run this backup/restore with sudo" ) do |val|
    options[:sudo] = "sudo"
  end  # -S --sudo
  opts.on( "-n", "--noop", "--dryrun", "--test",
           "Dry-run (test & display, no-op) mode" ) do |val|
    options[:noop]  = true
    options[:verbose] = true  # Dry-run implies verbose...
  end  # -n --noop
  opts.on( "-u", "--update", "--save",
           "Update (save) the configuration file; a configuration",
           "file is automatically created if it doesn't exist:",
           "#{CONFIGFILE}" ) do |val|
    options[:update] = true
  end  # -u --update
  opts.on( "-v", "--verbose", "--log", "Verbose mode" ) do |val|
    options[:verbose] = true
  end  # -v --verbose
  opts.on( "-d", "--debug", "=DebugLevel", Integer,
           "Show debug information (levels: 1, 2 or 3)" ) do |val|
    options[:debug] = val.to_i
  end  # -d --debug
  opts.on_tail( "-a", "--about", "Display program info" ) do |val|
    puts "#{PROGID}"
    puts "#{AUTHOR}"
    options[:about] = true
    exit true
  end  # -a --about
  # --- Set the banner & Help option ---
  opts.banner = "  Usage: #{PROGNAME} [options] [BackupDir]"
  opts.on_tail( "-?", "-h", "--help", "Display this help text" ) do |val|
    puts opts
    options[:help] = true
    exit true
  end  # -? --help
}.parse!  # leave residue-args in ARGV

# Common rsync options, always used here...
# note that --archive = --recursive --perms --links --times
#                       --owner --group --devices --specials
rcommon  = "-auh --stats"           # --archive --update --human-readable --stats
rcommon += " -n" if options[:noop]  # --dry-run
# Turn on verbose/progress output?
rverbose  = options[:verbose] ? " --progress" : ""
rverbose += " --itemize-changes" if options[:itemize]

# If an exclude-from file is specified (or default) and exists, use it:
if options[:exclude].locase == "none"
  exclfile, excloption = "«none»", ""
else
  exclfile, excloption = excludespec( options[:exclude], DEFEXCLFILE, " --exclude-from=" )
end

# If a SourceDirectory is specified, us it rather than the default:
sourcedir = dirspec( options[:sourcetree], DEFSOURCETREE )

# If a BackupDirectory is specified, use it rather than the default;
# the --backuptree spec, if given, trumps ARGV[0]:
options[:backuptree] ||= ARGV[0]
backupdir = dirspec( options[:backuptree], DEFBACKUPTREE )

# The full rsync command with options:
rsync  = "#{options[:sudo]} rsync #{rcommon}#{rverbose}#{excloption} "
# Operation:                 v-- Restoration ----------v   v-- Backup ---------------v
rsync += options[:recover] ? "#{backupdir} #{sourcedir}" : "#{sourcedir} #{backupdir}"

# Update the config-file, at user's request:
config_save( options ) if options[:update]

if options[:debug] >= DBGLVL2
  op = options[:recover] ? "Recover <=" : "Backup =>"
  $stderr.puts "\n           CONFIGDIR: '#{CONFIGDIR.color(:green)}'"
  $stderr.puts "          CONFIGFILE: '#{CONFIGFILE.color(:green)}'"
  $stderr.puts "         DEFEXCLFILE: '#{DEFEXCLFILE.color(:red)}'"
  $stderr.puts "  Actual excludefile: '#{exclfile.color(:red)}'"
  $stderr.puts "    Source directory: '#{sourcedir.color(:purple)}'"
  $stderr.puts "    Backup directory: '#{backupdir.color(:purple)}'"
  $stderr.puts "           Operation:  #{op.underline.color(:blue)}"
  $stderr.puts "  Full rsync command: '$#{rsync.color(:blue)}'\n\n"
end

if options[:recover]
  dir_error( "Backup", backupdir          ) if not File.exists?( backupdir )
  make_tree( "Source", sourcedir, options ) if not File.exists?( sourcedir )
else
  dir_error( "Source", sourcedir          ) if not File.exists?( sourcedir )
  make_tree( "Backup", backupdir, options ) if not File.exists?( backupdir )
end

%x{ #{rsync} }.lines { |ln| $stdout.puts ln }

exit true
