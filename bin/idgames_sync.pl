#!/usr/bin/env perl

use strict;
use warnings;
our $copyright =
    q|Copyright (c) 2011,2013 by Brian Manning <brian at xaoc dot org>|;

# For support with this file, please file an issue on the GitHub issue
# tracker: https://github.com/spicyjack/App-idGamesSync/issues

=head1 NAME

idgames_sync.pl - Synchronize a copy of the C<idGames> archive.

=head1 VERSION

Version v0.0.7

=cut

use version; our $VERSION = qv('0.0.7');

# shortcut to get the name of the file this script lives in
use File::Basename;
our $our_name = basename $0;

=head1 SYNOPSIS

Create or update a copy of the C<idGames> archive on the local host.

=cut

our @options = (
    # help/verbosity options
    q(help|h),
    q(debug|D|d),
    q(debug-files=i), # how many lines to parse/compare from ls-laR.gz
    q(debug-noexit), # don't exit when debugging
    q(verbose|v),
    q(version),
    q(examples|x),
    q(morehelp|m),
    # script options
    q(dry-run|n), # don't sync, just show steps that would be performed
    q(exclude|e=s@), # URLs to exclude when pulling from mirrors
    q(format|f=s), # reporting format
    q(path|p=s), # output path
    q(type|t=s@), # what type of information to report
    q(url|u=s), # URL to use for mirroring
    # logging options
    q(colorize!), # always colorize logs, no matter if a pipe is present or not
    q(loglevel|log|level|ll=s),
    # misc options
    q(prune-all), # prune files from the mirror, not just /newstuff
    q(sync-all), # sync everything, not just WADs
    q(show-mirrors), # show the mirrors array and exit
    q(create-mirror), # create a new mirror if ls-laR.gz not found at --path
    q(incoming), # show files in the /incoming directory
    q(dotfiles), # don't show dotfiles in reports - .filename
    q(headers), # show directory headers and blocks used
    q(tempdir=s), # temporary directory to use for tempfiles
    q(skip-ls-lar|skip-lslar), # update the ls-laR.gz file, then exit
    q(update-ls-lar|update-lslar), # update the ls-laR.gz file, then exit
    # combination options
    q(size-local|local-size|sl), # show size mismatches, missing local files
    q(size-same|ss), # show size mismatches and missing local files
);

=head1 OPTIONS

 perl idgames_sync.pl [options]

 Script options:
 -h|--help          Displays script options and usage
 -v|--verbose       Sets logging level to INFO, more verbose output
 --version          Shows script version, then exits
 -n|--dry-run       Don't sync content, explain script actions instead

 -p|--path          Path to the local copy of the idGames archive
 -t|--type          Report type(s) to use for reporting (see --morehelp)
 -f|--format        Output format, [full|more|simple] (see --morehelp)
 -u|--url           Use a specific URL instead of a random mirror
 --create-mirror    Authorize script to create a new copy of the mirror
 --sync-all         Synchronize everything, not just WAD directories
 --skip-ls-lar      Don't fetch 'ls-laR.gz' (after using '--update-ls-lar')
 --update-ls-lar    Update the local 'ls-laR.gz' file, then exit

 Run with '--examples' switch to see examples of script usage

 Run with '--morehelp' for more script options, and descriptions of the
 '--format' and '--type' options

=head1 DESCRIPTION

Using a current C<ls-lR.gz> listing file synchronized from an C<idGames>
archive mirror site, synchronizes an existing copy of the C<idGames> mirror on
the local host, or creates a new copy of the mirror on the local host if a
copy of the mirror does not already exist.

Script normally exits with a 0 status code, or a non-zero status code if any
errors were encountered.

=head1 OBJECTS

=head2 App::idGamesSync::Config

Configure/manage script options using L<Getopt::Long>.

=head3 Methods

=over

=cut

package App::idGamesSync::Config;

use strict;
use warnings;
use English qw( -no_match_vars );
use Pod::Usage; # prints POD docs when --help is called

sub new {
    my $class = shift;

    my $self = bless ({}, $class);

    # script arguments
    my %args;

    # parse the command line arguments (if any)
    my $parser = Getopt::Long::Parser->new();

    # pass in a reference to the args hash as the first argument
    $parser->getoptions( \%args, @options );

    # assign the args hash to this object so it can be reused later on
    $self->{_args} = \%args;

    # dump and bail if we get called with --help
    if ( $self->get(q(help)) ) { pod2usage(-exitstatus => 0); }

    # dump and bail if we get called with --help
    if ( $self->get(q(version)) ) {
        print __FILE__
            . qq(: synchronize files from 'idGames' mirrors to local host\n);
        print qq(version: $VERSION\n);
        print qq(copyright: $copyright\n);
        print qq|license: Same terms as Perl (Perl Artistic/GPLv1 or later)\n|;
        exit 0;
    }

    # set a flag if we're running on 'MSWin32'
    # this needs to be set before possibly showing examples because examples
    # will show differently on Windows than it does on *NIX (different paths
    # and prefixes)
    if ( $OSNAME eq q(MSWin32) ) {
        $self->set(is_mswin32 => 1);
    }

    # dump and bail if we get called with --examples
    if ( $self->get(q(examples)) ) {
        $self->show_examples();
        exit 0;
    }

    # dump and bail if we get called with --morehelp
    if ( $self->get(q(morehelp)) ) {
        $self->show_morehelp();
        exit 0;
    }


    # return this object to the caller
    return $self;
}

=item show_examples()

Show examples of script usage.

=cut

sub show_examples {
    my $self = shift;


    ### WINDOWS EXAMPLES ###
    if ( $self->defined(q(is_mswin32)) ) {

        print <<"WIN_EXAMPLES";

 =-=-= $our_name - $VERSION - USAGE EXAMPLES =-=-=

 Create a mirror:
 ----------------
 $our_name --path C:\\path\\to\\idgames\\dir --create-mirror

 # Use the 'simple' output format
 $our_name --path C:\\path\\to\\idgames\\dir --create-mirror \\
   --format=simple

 # Use the 'simple' output format, synchronize everything
 $our_name --path C:\\path\\to\\idgames\\dir --create-mirror \\
   --format=simple --sync-all

 Synchronize existing mirror:
 ----------------------------
 $our_name --path C:\\path\\to\\idgames\\dir

 # Use 'simple' output format; default format is 'more'
 $our_name --path C:\\path\\to\\idgames\\dir --format simple

 # Use 'simple' output format, synchronize everything
 $our_name --path C:\\path\\to\\idgames\\dir --format simple --sync-all

 "Dry-Run", or test what would be downloaded/synchronized
 --------------------------------------------------------
 # Update the 'ls-laR.gz' archive listing
 $our_name --path C:\\path\\to\\idgames\\dir --update-lslar

 # Then use '--dry-run' to see what will be updated; use 'simple' output
 # format
 $our_name --path C:\\path\\to\\idgames\\dir --format simple --dry-run

 # Same thing, but synchronize everything instead of just WADs
 $our_name --path C:\\path\\to\\idgames\\dir --format simple \\
   --dry-run --sync-all

 More Complex Usage Examples:
 ----------------------------
 # specific mirror, 'simple' output format, show all files being mirrored
 $our_name --path C:\\path\\to\\idgames\\dir \\
    --url http://example.com --format simple --type all

 # use random mirrors, exclude a specific mirror, 'simple' output format
 $our_name --path C:\\path\\to\\idgames\\dir --format simple \\
    --exclude http://some-mirror-server.example.com

 # use random mirrors, exclude a specific mirror,
 # specify temporary directory, 'full' output format
 $our_name --path C:\\path\\to\\idgames\\dir \\
    --exclude http://some-mirror-server.example.com \\
    --format full --tempdir C:\\path\\to\\temp\\dir

 # 'simple' output format, try to synchronize the '/incoming' directory
 # NOTE: this will cause download failures, please see '--morehelp' for a
 # longer explanation
 $our_name --path C:\\path\\to\\idgames\\dir --incoming

 # Show the list of mirror servers embedded into this script, then exit
 $our_name --show-mirrors

WIN_EXAMPLES

    } else {
        print <<"NIX_EXAMPLES";

 =-=-= $our_name - $VERSION - USAGE EXAMPLES =-=-=

 Create a mirror:
 ----------------
 $our_name --path /path/to/your/idgames/dir --create-mirror

 # Use the 'simple' output format
 $our_name --path /path/to/your/idgames/dir --create-mirror \\
   --format=simple

 # Use the 'simple' output format, synchronize everything
 $our_name --path /path/to/your/idgames/dir --create-mirror \\
   --format=simple --sync-all

 Synchronize existing mirror:
 ----------------------------
 $our_name --path /path/to/your/idgames/dir

 # Use 'simple' output format; default format is 'more'
 $our_name --path /path/to/your/idgames/dir --format simple

 # Use 'simple' output format, synchronize everything
 $our_name --path /path/to/your/idgames/dir --format simple --sync-all

 "Dry-Run", or test what would be downloaded/synchronized
 --------------------------------------------------------
 # Update the 'ls-laR.gz' archive listing
 $our_name --path /path/to/your/idgames/dir --update-lslar

 # Then use '--dry-run' to see what will be updated;
 # use 'simple' output format
 $our_name --path /path/to/your/idgames/dir --format simple --dry-run

 # Same thing, but synchronize everything instead of just WADs
 $our_name --path /path/to/your/idgames/dir --format simple \\
   --dry-run --sync-all

 More Complex Usage Examples:
 ----------------------------
 # specific mirror, 'simple' output format, show all files being mirrored
 $our_name --path /path/to/your/idgames/dir \\
    --url http://example.com --format simple --size-same

 # use random mirrors, exclude a specific mirror, 'simple' output format
 $our_name --path /path/to/your/idgames/dir \\
    --exclude http://some-mirror-server.example.com --format simple

 # use random mirrors, exclude a specific mirror,
 # specify temporary directory, 'full' output format
 $our_name --path /path/to/your/idgames/dir \\
    --exclude http://some-mirror-server.example.com \\
    --format full --tempdir /path/to/temp/dir

 # 'simple' output format, try to synchronize the '/incoming' directory
 # NOTE: this will cause download failures, please see '--morehelp' for a
 # longer explanation
 $our_name --path /path/to/your/idgames/dir --incoming

 # Show the list of mirror servers embedded into this script, then exit
 $our_name --show-mirrors

NIX_EXAMPLES

    }
}

=item show_morehelp()

Show more help information on how to use the script and how the script
functions.

=cut

sub show_morehelp {

print <<MOREHELP;

 =-=-= $our_name - $VERSION - More Help Screen =-=-=

 Misc. script options:
 ---------------------
 -x|--examples      Show examples of script execution
 -m|--morehelp      Show extended help info (format/type specifiers)
 -e|--exclude       Don't use these mirror URL(s) for syncing
 --dotfiles         Show "hidden" files, Example: .message/.listing
 --headers          Show directory headers and blocks used in output
 --incoming         Show files located in the /incoming directory
 --show-mirrors     Show the current set of mirrors then exit
 --size-local       Combination of '--type size --type local' (default)
 --size-same        Combination of '--type size --type same'
 --tempdir          Temporary directory to use when downloading files

 Script debugging options:
 -------------------------
 -d|--debug         Sets logging level to DEBUG, tons of output
 --debug-noexit     Don't exit if --debug is set (ignores --debug-files)
 --debug-files      Sync this many files before exiting (default: 50)
                    Requires '--debug'
 --colorize         Always colorize log output (when piping log output)

 Notes about script behaivor:
 ----------------------------
 By default, the script will query a random mirror for each file that needs to
 be synchronized unless the --url switch is used to specify a specific mirror.

 Files located in the /incoming directory will not be synchronized by default
 unless --incoming is used.  Most FTP sites won't let you download/retrieve
 files from /incoming due to file/directory permissions on the FTP server;
 it's basically useless to try to download files from that directory, it will
 only generate errors.

 Report Types (for use with the --type switch):
 ----------------------------------------------
 Use these report types with the '--type' flag; note '--type' can be specified
 multiple times.
 - headers  - Print directory headers and directory block sizes
 - local    - Files in the archive that are missing on local disk
 - archive  - Files on the local disk not listed in the archive
 - size     - Size differences between the local file and archive file
 - same     - Same size file exists on disk and in the archive

 The default report type is "size + local" (same as '--size-local' below).

 Combined report types:
 ----------------------
 Use these combined report types instead of specifying '--type' multiple
 times.
 --size-local   (size + local) Show file size mismatches, and files missing on
                local system; this is the default report type
 --size-same    (size + same) Show all files listed in the archive, both with
                valid local files and with size mismatched local files

 Output formats (for use with the --format switch):
 --------------------------------------------------
 - full     One line per file/directory attribute
 - more     Shows filename, date/time, size on one line, file attributes on
            the next line
 - simple   One file per line, with status flags to the left of the filename
            Status flags:
            - FF = This object is a file
            - DD = This object is a directory
            - FS = This object is a file, file size mismatch
            - !! = File/directory is missing file on local system

 The default output format is "more".

MOREHELP
}

=item get($key)

Returns the scalar value of the key passed in as C<key>, or C<undef> if the
key does not exist in the L<App::idGamesSync::Config> object.

=cut

sub get {
    my $self = shift;
    my $key = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    if ( exists $args{$key} ) { return $args{$key}; }
    return undef;
}

=item set(key => $value)

Sets in the L<App::idGamesSync::Config> object the key/value pair passed in
as arguments.  Returns the old value if the key already existed in the
L<App::idGamesSync::Config> object, or C<undef> otherwise.

=cut

sub set {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    if ( exists $args{$key} ) {
        my $oldvalue   = $args{$key};
        $args{$key}    = $value;
        $self->{_args} = \%args;
        return $oldvalue;
    } else {
        $args{$key}    = $value;
        $self->{_args} = \%args;
    } # if ( exists $args{$key} )
    return undef;
}

=item get_args( )

Returns a hash containing the parsed script arguments.

=cut

sub get_args {
    my $self = shift;
    # hash-ify the return arguments
    return %{$self->{_args}};
}

=item defined($key)

Returns "true" (C<1>) if the value for the key passed in as C<key> is
C<defined>, and "false" (C<0>) if the value is undefined, or the key doesn't
exist.

=back

=cut

sub defined {
    my $self = shift;
    my $key = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    # Can't use Log4perl here, since it hasn't been set up yet
    if ( exists $args{$key} ) {
        #warn qq(exists: $key\n);
        if ( defined $args{$key} ) {
            #warn qq(defined: $key; ) . $args{$key} . qq(\n);
            return 1;
        }
    }
    return 0;
}

################
# package main #
################
package main;

### external packages
use Date::Format; # strftime
use Devel::Size; # for profiling filelist hashes (/newstuff, archive)
use Digest::MD5; # comparing the ls-laR.gz files
use English;
use File::Copy;
use File::Find::Rule;
use File::stat;
use Getopt::Long;
use IO::File;
use IO::Uncompress::Gunzip qw($GunzipError);
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
#use LWP::UserAgent;
use Mouse; # sets strict and warnings
use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;

### local packages
use App::idGamesSync::ArchiveDirectory;
use App::idGamesSync::ArchiveFile;
use App::idGamesSync::LocalDirectory;
use App::idGamesSync::LocalFile;
use App::idGamesSync::LWPWrapper;
use App::idGamesSync::Reporter;
use App::idGamesSync::RuntimeStats;

use constant {
    DEBUG_LOOPS => 50,
    PERMS       => 0,
    HARDLINKS   => 1,
    OWNER       => 2,
    GROUP       => 3,
    SIZE        => 4,
    MONTH       => 5,
    DATE        => 6,
    YEAR_TIME   => 7,
    NAME        => 8,
    TOTAL_FIELDS=> 9,
};



=head1 DESCRIPTION

Script normally exits with a 0 status code, or a non-zero status code if any
errors were encountered.

=cut

    # force writes in output to STDOUT
    $| = 1;

    # creating a Config object will check for things like '--help',
    # '--examples', and '--morehelp'
    my $cfg = App::idGamesSync::Config->new();

    # parent directory
    my $parent = q();
    # flag set whenever we're parsing files in/beneath the /incoming directory
    my $incoming_dir_flag = 0;

    # default log level
    my $log4perl_conf = qq(log4perl.rootLogger = WARN, Screen\n);
    if ( $cfg->defined(q(verbose)) && $cfg->defined(q(debug)) ) {
        die(q(Script called with --debug and --verbose; choose one!));
    } elsif ( $cfg->defined(q(debug)) ) {
        $log4perl_conf = qq(log4perl.rootLogger = DEBUG, Screen\n);
    } elsif ( $cfg->defined(q(verbose)) ) {
        $log4perl_conf = qq(log4perl.rootLogger = INFO, Screen\n);
    }

    # if 'colorize' is undefined, set a default (needed for Log4perl check
    # below)
    if ( ! $cfg->defined(q(colorize)) ) {
        # colorize if STDOUT is connected to a terminal
        if ( -t STDOUT ) {
            $cfg->set(colorize => 1);
        } else {
            $cfg->set(colorize => 0);
        }
        # Unless we're running on Windows, in which case, don't colorize
        # unless --colorize is explicitly used, which would cause this whole
        # block to get skipped
        if ( $cfg->defined(q(is_mswin32)) ) {
            $cfg->set(colorize => 0);
        }
    }

    # color log output
    if ( $cfg->get(q(colorize)) ) {
        $log4perl_conf .= q(log4perl.appender.Screen )
            . qq(= Log::Log4perl::Appender::ScreenColoredLevels\n);
    } else {
        $log4perl_conf .= q(log4perl.appender.Screen )
            . qq(= Log::Log4perl::Appender::Screen\n);
    }

    # the rest of the log4perl setup
    $log4perl_conf .= qq(log4perl.appender.Screen.stderr = 1\n)
        . qq(log4perl.appender.Screen.layout = PatternLayout\n)
        . q(log4perl.appender.Screen.layout.ConversionPattern )
        # %r: number of milliseconds elapsed since program start
        # %p{1}: first letter of event priority
        # %4L: line number where log statement was used, four numbers wide
        # %M{1}: Name of the method name where logging request was issued
        # %m: message
        # %n: newline
        . qq|= [%8r] %p{1} %4L (%M{1}) %m%n\n|;

    Log::Log4perl->init(\$log4perl_conf);
    my $log = Log::Log4perl->get_logger();
    $log->debug(q(##### ) . __FILE__ . qq( - $VERSION #####));
    $log->debug(qq(script start; ) . time2str(q(%C), time));

    my @exclude_urls;
    if ( $cfg->defined(q(exclude)) ) {
        @exclude_urls = @{$cfg->get(q(exclude))};
    }

    # set a temporary directory; this directory is used when downloading
    # files, App::idGamesSync::LWPWrapper downloads to the file directly
    # instead of downloading to an object in memory
    if ( ! $cfg->defined(q(tempdir)) ) {
        if ( defined $ENV{TEMP} ) {
            # Windows usually sets %TEMP% as well
            $cfg->set(tempdir => $ENV{TEMP});
            $log->debug(q(Using ENV{TEMP} for tempdir));
        } elsif ( defined $ENV{TMP} ) {
            $cfg->set(tempdir => $ENV{TMP});
            $log->debug(q(Using ENV{TMP} for tempdir));
        } elsif ( defined $ENV{TMPDIR} ) {
            $cfg->set(tempdir => $ENV{TMPDIR});
            $log->debug(q(Using ENV{TMPDIR} for tempdir));
        } else {
            $cfg->set(tempdir => q(/tmp));
            $log->debug(q(Using '/tmp' for tempdir));
        }
        $log->debug(q(Using ) . $cfg->get(q(tempdir)) . q( for tempdir));
    }
    my $lwp = App::idGamesSync::LWPWrapper->new(
        base_url        => $cfg->get(q(url)),
        exclude_urls    => \@exclude_urls,
        tempdir         => $cfg->get(q(tempdir)),
    );

    if ( $cfg->defined(q(show-mirrors)) ) {
        print qq(Current mirror URLs:\n);
        foreach my $mirror ( $lwp->get_mirror_list() ) {
            print qq(- $mirror\n);
        }
        exit 0;
    }

    if ( $log->is_debug ) {
        $log->debug(q(Dumping %args hash:));
        my %args = $cfg->get_args();
        warn(Dumper {%args});
    }

    $log->logdie(q(Must specify path directory with --path))
        unless ( $cfg->defined(q(path)) );

    if ( ! $cfg->defined(q(is_mswin32)) ) {
        # For *NIX, append a forward slash on to the directory name so other
        # paths don't need the forward slash later on
        if ( $cfg->get(q(path)) !~ /\/$/ ) {
            $cfg->set(path => $cfg->get(q(path)) . q(/));
        }
    } else {
        # same for Windows, but append a backslash
        if ( $cfg->get(q(path)) !~ /\\$/ ) {
            $cfg->set(path => $cfg->get(q(path)) . q(\\));
        }
    }

    # create the App::idGamesSync::Reporter object
    my $reporter = App::idGamesSync::Reporter->new(
        show_dotfiles => $cfg->get(q(dotfiles)) );

    ### REPORT TYPES
    # the default report type is now size-local
    my @report_types = @{$reporter->default_report_types};
    if ( $cfg->defined(q(size-same)) ) {
        @report_types = qw(size same);
    }

    if ( $cfg->defined(q(type)) ) {
        my @reports = @{$cfg->get(q(type))};
        my @requested_types;
        foreach my $type ( @reports ) {
            if (scalar(grep(/$type/i, @{$reporter->valid_report_types})) < 1) {
                $log->logdie(qq(Report type '$type' is not a valid type));
            } else {
                push(@requested_types, $type);
            }
        }
        @report_types = @requested_types;
    }
    $reporter->report_types(\@report_types);
    $log->debug(q(Report types set to: )
        . join(":", @{$reporter->report_types}));

    ### REPORT FORMATS
    my $report_format = $reporter->default_report_format;
    my @valid_report_formats = @{$reporter->valid_report_formats};
    if ( $cfg->defined(q(format)) ) {
        $report_format = $cfg->get(q(format));
        if (scalar(grep(/$report_format/i,
            @{$reporter->valid_report_formats})) < 1) {
                $log->logdie(qq(Report format '$report_format' )
                    . q(is not a valid format));
        }
    }
    $reporter->report_format = $report_format;
    $log->debug(q(Report format set to: ) . $reporter->report_format);

    # skip syncing of dotfiles by default
    if ( ! $cfg->defined(q(dotfiles)) ) {
        $cfg->set(dotfiles => 0);
    }

    my $stats = App::idGamesSync::RuntimeStats->new(
        dry_run       => $cfg->defined(q(dry-run)),
        report_format => $report_format
    );
    $stats->start_timer();

    # a list of files/directories were sync'ed with a mirror, either because
    # they're missing from the local system, or for files, the file is the
    # wrong size
    my @synced_files;
    my $total_archive_size = 0;
    my $dl_lslar_file;
    my $lslar_file = $cfg->get(q(path)) . q(ls-laR.gz);
    my $lslar_stat = stat($lslar_file);
    $log->debug(qq(Set lslar_file to $lslar_file));
    if ( ! -r $lslar_file && ! $cfg->defined(q(create-mirror)) ) {
        $log->fatal(qq(Can't read/find the 'ls-laR.gz' file!));
        $log->fatal(qq|(Checked: $lslar_file)|);
        $log->fatal(qq(If you are creating a new mirror, please use the));
        $log->fatal(qq('--create-mirror' switch; otherwise, check that));
        $log->fatal(qq(the '--path' switch is pointing to the directory));
        $log->fatal(qq(where the local copy of 'idgames' is located.));
        $log->logdie(qq(Exiting script...));
    }

    ### UPDATE ls-laR.gz ###
    if ( ! $cfg->defined(q(dry-run)) && ! $cfg->defined(q(skip-ls-lar)) ) {
        $log->debug(qq(Fetching 'ls-laR.gz' file listing));
        # if a custom URL was specified, use that here instead
        my $lslar_url = $lwp->master_mirror;
        if ( $cfg->defined(q(url)) ) {
            $lslar_url = $cfg->get(q(url));
        }
        # returns undef if there was a problem fetching the file
        $dl_lslar_file = $lwp->fetch(
            filepath => q(ls-laR.gz),
            base_url => $lslar_url,
        );
        if ( ! defined $dl_lslar_file ) {
            $log->logdie(qq(Error downloading ls-laR.gz file));
        }
        $log->debug(qq(Received tempfile $dl_lslar_file from fetch method));
        my $dl_lslar_stat = stat($dl_lslar_file);

        my $in_fh = IO::File->new(qq(< $lslar_file));
        # create the digest object outside of any nested blocks
        my $md5 = Digest::MD5->new();
        # get the digest for the local file, if the local file exists
        if ( defined $in_fh ) {
            $md5->addfile($in_fh);
            # close the local file filehandle
            $in_fh->close();
        } else {
            # if there's no previous copy of the archive on disk, just use
            # a bogus file for the stat object, and bogus string for the
            # checksum;
            # no need to close the filehandle, it will already be 'undef'
            if ( $cfg->defined(q(is_mswin32)) ) {
                $lslar_stat = stat(q(C:));
            } else {
                $lslar_stat = stat(q(/dev/null));
            }
            $md5->add(q(bogus file digest));
        }
        my $local_digest = $md5->hexdigest();

        # get the digest for the synchronized file
        my $dl_fh = IO::File->new(qq(< $dl_lslar_file));
        # $md5 has already been reset with the call to hexdigest() above
        $md5->addfile($dl_fh);
        my $archive_digest = $md5->hexdigest();
        # close the filehandle
        $dl_fh->close();
        # check to see if the synchronized ls-laR.gz file is the same file
        # on disk by comparing MD5 checksums for the buffer and file
        print q(- Local file size:   ) . $lslar_stat->size
            . qq(;  checksum: $local_digest\n);
        print q(- Archive file size: ) . $dl_lslar_stat->size
            . qq(;  checksum: $archive_digest\n);
        if ( $local_digest ne $archive_digest ) {
            #my $out_fh = IO::File->new(qq(> $lslar_file));
            print qq(- ls-laR.gz Checksum mismatch...\n);
            print qq(- Replacing file: $lslar_file\n);
            print qq(- With file: $dl_lslar_file\n);
            move($dl_lslar_file, $lslar_file);
        } else {
            print qq(- $lslar_file and archive copy match!\n);
            $log->debug(qq(Unlinking $dl_lslar_file));
            unlink $dl_lslar_file;
        }
        # exit here if --update-ls-lar was used
        if ( $cfg->defined(q(update-ls-lar)) ) {
            print qq(- ls-laR.gz synchronized, exiting program\n);
            exit 0;
        }
    }

    my $gunzip = IO::Uncompress::Gunzip->new($lslar_file, Append => 1);
    $log->logdie(q(Could not create IO::Uncompress::Gunzip object; ) .
        $GunzipError) unless (defined $gunzip);
    my ($buffer, $uncompressed_bytes);
    # keep reading into $buffer until we reach EOF
    until ( $gunzip->eof() ) {
        $uncompressed_bytes = $gunzip->read($buffer);
    }
    $log->info(qq(ls-laR.gz uncompressed size: ) . length($buffer));

    ### PARSE ls-laR.gz FILE ###
    my %idgames_filelist;
    my $current_dir;
    my %newstuff_dir;
    IDGAMES_LINE: foreach my $line ( split(/\n/, $buffer) ) {
        # skip blank lines
        next if ( $line =~ /^$/ );
        $log->debug(qq(line: >>>$line<<<));
        my @fields = split(/\s+/, $line);
        my $name_field;
        # we're not expecting any more than TOTAL_FIELDS fields returned
        # from the above split() call
        if ( scalar(@fields) > TOTAL_FIELDS ) {
            $log->debug(q(HEY! got ) . scalar(@fields) . qq( fields!));
            my @name_fields = splice(@fields, NAME, scalar(@fields));
            $log->debug(qq(name field had spaces; joined name is: )
                . join(q( ), @name_fields));
            $name_field = join(q( ), @name_fields);
        } else {
            $name_field = $fields[NAME];
        }
        # a file, the directory bit will not be set in the listing output
        if ( defined $name_field ) {
            $log->debug(qq(Reassembled file/dir name: '$name_field'));
        }
        if ( $fields[PERMS] =~ /^-.*/ ) {
            # skip this file if it's inside the /incoming directory
            # this can't be combined with the --dotfiles check below because
            # that requires a local file object, whereas the incoming dir
            # check works off of the archive directory
            if ( $incoming_dir_flag && ! $cfg->defined(q(incoming)) ) {
                $log->debug(q(file in /incoming, but --incoming not used));
                next IDGAMES_LINE;
            }

            $log->debug(qq(Creating archive file object '$name_field'));
            my $archive_file = App::idGamesSync::ArchiveFile->new(
                parent_path     => $current_dir,
                perms           => $fields[PERMS],
                hardlinks       => $fields[HARDLINKS],
                owner           => $fields[OWNER],
                group           => $fields[GROUP],
                size            => $fields[SIZE],
                mod_time        => $fields[MONTH] . q( )
                    . $fields[DATE] . q( ) . $fields[YEAR_TIME],
                name            => $name_field,
            );
            $total_archive_size += $archive_file->size;
            $log->debug(qq(Creating local file object '$name_field'));
            my $local_file = App::idGamesSync::LocalFile->new(
                opts_path   => $cfg->get(q(path)),
                archive_obj => $archive_file,
                is_mswin32  => $cfg->defined(q(is_mswin32)),
            );
            # stat the file to see if it exists on the local system, and to
            # populate file attribs if it does exist
            $local_file->stat_local();

            # add the file to the filelist
            $idgames_filelist{$local_file->absolute_path}++;

            $reporter->write_record(
                archive_obj    => $archive_file,
                local_obj      => $local_file,
            );
            if ( $local_file->is_newstuff ) {
                    # add this file to the list of files that should be in
                    # /newstuff
                    $newstuff_dir{$local_file->absolute_path}++;
                    $log->debug(q(Added file to /newstuff list));
            }
            if ( $local_file->needs_sync ) {
                # skip syncing dotfiles unless --dotfiles was used
                if ($local_file->is_dotfile && ! $cfg->get(q(dotfiles))) {
                    $log->debug(q(dotfile needs sync, missing --dotfiles));
                    next IDGAMES_LINE;
                }
                # skip syncing non-WAD files/metafiles unless --sync-all was
                # used
                if (! ($local_file->is_wad_dir
                    || $local_file->is_metafile
                    || $local_file->is_newstuff)
                    && ! $cfg->defined(q(sync-all))){
                    $log->debug(q(Non-WAD file needs sync, missing --sync-all));
                    next IDGAMES_LINE;
                }
                if ( $cfg->defined(q(dry-run)) ) {
                    $log->debug(q(Needs sync, dry-run set; parsing next line));
                    push(@synced_files, $archive_file);
                    next IDGAMES_LINE;
                } else {
                    my $sync_status = $local_file->sync( lwp => $lwp );
                    if ( $sync_status ) {
                        # add the file to the list of synced files
                        # used later on in reporting
                        push(@synced_files, $archive_file);
                    }
                }
                $local_file->stat_local();
                # check here that the downloaded file matches the size
                # shown in ls-laR.gz; make another call to stat_local; make
                # another call to stat_local
                if ( ($local_file->size != $archive_file->size)
                    && ! $local_file->is_metafile ) {
                    $log->warn(q(Downloaded size: ) . $local_file->size
                        . q( doesn't match archive file size: )
                        . $archive_file->size);
                }
            } else {
                $log->debug(q(File exists on local system, no need to sync));
            }
        # the directory bit is set in the listing output
        } elsif ( $fields[PERMS] =~ /^d.*/ ) {
            # skip this directory if it's inside the /incoming directory
            if ( $incoming_dir_flag && ! $cfg->defined(q(incoming)) ) {
                $log->debug(q(dir in /incoming, but --incoming not used));
                next IDGAMES_LINE;
            }
            $log->debug(qq(Creating archive dir object '$name_field'));
            my $archive_dir = App::idGamesSync::ArchiveDirectory->new(
                parent_path     => $current_dir,
                perms           => $fields[PERMS],
                hardlinks       => $fields[HARDLINKS],
                owner           => $fields[OWNER],
                group           => $fields[GROUP],
                size            => $fields[SIZE],
                mod_time        => $fields[MONTH] . q( )
                    . $fields[DATE] . q( ) . $fields[YEAR_TIME],
                name            => $name_field,
                total_blocks    => 0,
            );
            $log->debug(qq(Creating local dir object '$name_field'));
            my $local_dir = App::idGamesSync::LocalDirectory->new(
                opts_path       => $cfg->get(q(path)),
                archive_obj    => $archive_dir,
            );
            $local_dir->stat_local();
            $reporter->write_record(
                archive_obj    => $archive_dir,
                local_obj      => $local_dir,
            );
            if ( $local_dir->needs_sync ) {
                if ( ! $cfg->defined(q(dry-run)) ) {
                    $local_dir->sync( lwp => $lwp );
                }
            } else {
                $log->debug(qq(Directories do not need to be synchronized));
            }
        # A new directory entry
        } elsif ( $fields[PERMS] =~ /^\.[\/\w\-_\.]*:$/ ) {
            print qq(=== Entering directory: )
                . $fields[PERMS] . qq( ===\n)
                if ( $cfg->defined(q(headers)) );
            # scrape out the directory name sans trailing colon
            $current_dir = $fields[PERMS];
            $current_dir =~ s/:$//;
            $current_dir =~ s/^\.//;
            if ( $current_dir =~ /^\/incoming.*/ ) {
                $log->debug(qq(Parsing subdirectory: $current_dir));
                $log->debug(q(/incoming directory; setting flag));
                $incoming_dir_flag = 1;
            } else {
                if ($current_dir =~ /^$/ ) {
                    $log->debug(qq(Setting current directory to: <root>));
                } else {
                    $log->debug(qq(Setting current directory to: $current_dir));
                }
                $log->debug(q(Clearing /incoming directory flag));
                $incoming_dir_flag = 0;
            }
        } elsif ( $line =~ /^total (\d+)$/ ) {
            # $1 got populated in the regex above
            my $dir_blocks = $1;
            print qq(- total blocks taken by this directory: $dir_blocks\n)
                if ( $cfg->defined(q(headers)) );
        } elsif ( $line =~ /^lrwxrwxrwx.*/ ) {
            print qq(- found a symlink: $current_dir\n)
                if ( $log->is_info() );
        } else {
            $log->warn(qq(Unknown line found in input data; >$line<));
        }
        if ( $log->is_debug() ) {
            # don't worry about counters or constants if --debug-noexit was
            # used
            next IDGAMES_LINE if ( $cfg->defined(q(debug-noexit)) );
            # check to see if --debug-files was used
            if ( $cfg->defined(q(debug-files)) ) {
                if ( scalar(keys(%idgames_filelist))
                        > $cfg->get(q(debug-files)) ) {
                    $log->debug(q|reached | . $cfg->get(q(debug-files))
                        . q( files));
                    $log->debug(q(Exiting script early due to --debug flag));
                    last IDGAMES_LINE;
                }
            } else {
                # go with the constant 'DEBUG_LOOPS'
                if ( scalar(keys(%idgames_filelist)) == DEBUG_LOOPS ) {
                    $log->debug(q|DEBUG_LOOPS (| . DEBUG_LOOPS
                        . q|) reached...|);
                    $log->debug(q(Exiting script early due to --debug flag));
                    last IDGAMES_LINE;
                }
            }
        }
    } # foreach my $line ( split(/\n/, $buffer) )

    # check the contents of /newstuff, make sure that files have been deleted
    # if they don't belong there anymore
    my $deleted_file_count = 0;

    # all of the files in the local mirror
    my @local_idgames_files = File::Find::Rule
        ->file
        ->in($cfg->get(q(path)));

    # are we only deleting from newstuff?
    my @local_file_check;
    if ( $cfg->defined(q(prune-all)) ) {
        $log->debug(q(Checking local archive for files to delete));
        $log->debug(q(There are currently ) . scalar(keys(%idgames_filelist))
            . q( files on the 'idgames' Archive mirrors));
        $log->debug(q(There are currently ) . scalar(@local_idgames_files)
            . q( files in the local copy of 'idGames' archive));
        @local_file_check = @local_idgames_files;
    } else {
        $log->debug(q(Checking /newstuff for files to delete));
        $log->debug(q(/newstuff currently should have )
            . scalar(keys(%newstuff_dir)) . q( files));
        my $newstuff_path = $cfg->get(q(path)) . q(newstuff);
        @local_file_check = grep(/$newstuff_path/, @local_idgames_files);
    }

    foreach my $local_file ( sort(@local_file_check) ) {
        my $check_file;
        my $delete_location;
        # see if the $check_file exists in the archive (and in /newstuff)
        if ( $cfg->defined(q(prune-all)) ) {
            $check_file = $idgames_filelist{$local_file};
            $delete_location = "non-archive";
        } else {
            $check_file = $idgames_filelist{$local_file};
            $delete_location = "/newstuff";
        }
        # if the file does not exist in the archive/in /newstuff
        if ( ! defined $check_file ) {
            if ( $cfg->defined(q(dry-run)) ) {
                print qq(* Would delete $delete_location file: $local_file\n);
            } else {
                print qq(* Deleting $delete_location file: $local_file\n);
                if ( unlink $local_file ) {
                    $deleted_file_count++;
                } else {
                    $log->error(qq(Can't unlink $local_file: $!));
                }
            }
        }
    }

    # stop the timer prior to calculating stats
    $stats->stop_timer();

    # calc stats and write them out
    $stats->write_stats(
        total_synced_files      => \@synced_files,
        total_archive_files     => scalar(keys(%idgames_filelist)),
        total_archive_size      => $total_archive_size,
        newstuff_file_count     => scalar(keys(%newstuff_dir)),
        deleted_file_count      => $deleted_file_count,
    );
    exit 0;

=head1 AUTHOR

Brian Manning, C<< <brian at xaoc dot org> >>

=head1 BUGS

Please report any bugs or feature requests to
L<https://github.com/spicyjack/App-idGamesSync/issues>.  I will be notified,
and then you'll automatically be notified of progress on your bug as I make
changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc idgames_sync.pl

You can also look for information at:

=over 4

=item * App::idGamesSync GitHub project page

L<https://github.com/spicyjack/App-idGamesSync>

=item * App::idGamesSync GitHub issues page

L<https://github.com/spicyjack/App-idGamesSync/issues>

=back

=head1 ACKNOWLEDGEMENTS

Perl, the Doom Wiki L<http://www.doomwiki.org> for lots of the documentation,
all of the various Doom source porters, and id Software for releasing the
source code for the rest of us to make merry mayhem with.

=head1 COPYRIGHT & LICENSE

Copyright (c) 2011, 2013 Brian Manning, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
