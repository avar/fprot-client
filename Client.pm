package FProt::Client;
use strict;
use IO::Socket::INET ();

our $VERSION = '0.09';

# The fpscand protocol this library expects
our $FPSCAND_PROTOCOL     = '1.0';
# Default host/port of the fpscand
our $FPSCAND_DEFAULT_HOST = '127.0.0.1';
our $FPSCAND_DEFAULT_PORT = '10200';

# Field in the help line are seperated by single spaces, between that
# and \S+ we're being much more forgiving about the format than we
# need to be, but this gets the job done just fine.
our $FPSCAND_HELP_FORMAT = qr/
    ^
    # FPSCAND:5.99.1
    FPSCAND:(\S+)
    \s*
    # ENGINE:4.3.48
    ENGINE:(\S+)
    \s*
    # PROTOCOL:1.0
    PROTOCOL:(\S+)
    \s*
    # SIGNATURE:2007042619259c9f739253754160e8b359e6b43a5f67
    SIGNATURE:(\S+)
    \s*
    # UPTIME:0:00:59:22
    UPTIME:(\S+)
/xs;

# scan file line when reporting a file in an archive
our $FPSCAND_FILE_FORMAT_ARCHIVE = qr/^([0-9]+) <(.*?)> (.*?)->(.*)/s;
# scan file line when reporting a simple file
our $FPSCAND_FILE_FORMAT_FILE    = qr/^([0-9]+) <(.*?)> (.*)/s;
# scan file line when an error occurred
our $FPSCAND_FILE_FORMAT_ERR     = qr/^([0-9]+) <(.*?)>/s;

# Private croak sub so as to not load Carp.pm every time
my $croak = sub
{
    require Carp;
    goto &Carp::croak;
};

my $hash2str = sub
{
    my ($conf) = @_;
    my $ret    = '';

    while (my ($key, $value) = each %$conf) {
        # Turn `foo', `-foo', `--foo' into `--foo'
        $key =~ s/^-*/--/s;

        # --option=5 or --option?
        $value = '=' . $value if defined $value;
        $value = ''       unless defined $value;

        $ret .= " $key$value";
    }

    $ret;
};

=head1 NAME

FProt::Client - Client interface to the fpscand(1) virus scanning daemon

=head1 SYNOPSIS

    use FProt::Client;

    # Spawn an object configured to use the default 127.0.0.1:10200 host/port
    my $fpc = FProt::Client->new;

    # A host and/or port can optionally be supplied to override the default
    my $fpc = FProt::Client->new(
        host => '10.0.0.1', # Scanning box
        port => 10200,      # Default port
    );

    # Check if we could connect to the daemon
    warn "Connected" if $fpc->ping;

    # Scan a single file
    my ($status, $msg) = $fpc->scan_file('/etc/crontab');
    if ($status & 0x03) {
        print "/etc/crontab is clean\n";
    }

    # Scan with options (see SCANNING OPTIONS in fpscand(8))
    my %opt = (scanlevel => 3, archive => 99);
    my ($status, $msg) = $fpc->scan_file(\%opt, '/etc/crontab');
    if ($status & 0x03) {
        print "/etc/crontab is clean\n";
    }

    my ($status, $msg, $file, $archive_item) = $fpc->scan_file('/etc/crontab');

    # Scan a stream (also accepts an optional hashref as the first argument)
    use File::stat;
    my $file = 'README';
    open $fh, '<', $file or die $!;
    my ($status, $msg, $file, $archive_item) = $fpc->scan_stream($file, $fh, stat($file_txt)->size);

    # Close the connection with the daemon, called automatically by
    # DESTROY
    $fpc->quit;

=head1 DESCRIPTION

Provides an interface to the fpscand(1) virus scanning daemon. The
daemon is capable of scanning both files on its local machine and
files that are sent to it over the socket (currently limited by the
daemon to 10MB).

=head1 METHODS

=head2 new

Constructor, only configures the object with the host and port it
should connect and does not initiate a connection (see L</ping> for
testing the connection). A connection is lazily initiated when one of
the methods that require it below are called.

Optional arguments:

=over 4

=item host

The host or IP address to connect to, defaults to B<127.0.0.1> which
is the interface B<fpscand> binds to by default.

=item port

The TCP port to connect to, defaults to B<10200> which is the default
B<fpscpand> port.

=back

=cut

sub new
{
    my $pkg = shift;

    my $self = {
        host => $FPSCAND_DEFAULT_HOST,
        port => $FPSCAND_DEFAULT_PORT,
        @_,
    };

    # Sanity check arguments
    $croak->("host argument supplied with host:port use the port argument for ports")
        if $self->{host} =~ /.+:[0-9]+$/; # FIXME: is this IPv6-safe?
    $croak->("Non-numeric port given to constructor")
        if $self->{port} =~ /[^0-9]/;

    bless $self => $pkg;
}

=head2 ping

Checks if a connection can be established with the daemon.

=cut

sub ping
{
    my ($self) = @_;

    local ($!, $@); # $! too just to be safe..
    eval { $self->info };
    $@ ? 0 : 1
}

=head2 scan_file

Scan a given absolute path to a file. A hashref of scanning option
key-values can be optionally given as the first argument to pass
options to fpscand (see B<SCANNING OPTIONS> in fpscand(8)).

A list of values is returned:

=over 4

=item An infection code

An integer indicating the clean status of the file, see
L<return codes|/Return codes> for an explanation of the return values.

=item A status message

A human-readable message indicating the status of the file.

=item The file name

The file name as B<fpscand> returns it, this will be the full path to
the file.

=item Archive item

When scanning archives (F<.zip>, F<.tar> etc.) this will be the name
of a suspicious file in the archive. There is no fourth field for
normal files.

=back

=cut

sub scan_file
{
    # splice an empty config into $_[1] unless one exists
    splice @_, 1, 0, {} unless ref $_[1] eq 'HASH';

    my ($self, $conf, $file) = @_;
    my $confstr = $hash2str->($conf);

    my $res = $self->command("scan$confstr file $file\n");

    $self->parse_line($res);
}

=head2 scan_stream

Like L</scan_file> but scans a stream. Takes three additional
arguments instead of a filename, example:

    use File::stat;
    open $fh, '<', $file or die $!;
    my @ret = $fpc->scan_stream($file, $fh, stat($file)->size);

=cut

sub scan_stream
{
    # splice an empty config into $_[1] unless one exists
    splice @_, 1, 0, {} unless ref $_[1] eq 'HASH';

    my ($self, $conf, $id, $fh, $len) = @_;
    my $confstr = $hash2str->($conf);

    my $socket = $self->socket;
    my ($n, $buf);

    $socket->print("scan$confstr stream $id size $len\n");
    while (($n = read($fh, $buf, 2**12))) {
        $socket->print($buf);
    }

    $croak->("Read failed: $!") unless defined $n;

    chomp(my $res = $socket->getline);

    $self->parse_line($res);
}

=head2 queue_file

TODO: implement

=cut

sub queue_file
{
    die "Unimplemented";
    my ($self, $file) = @_;

    # Send the queue command unless we're already in the queue
    unless ($self->{queued}) {
        $self->socket->print("queue\n");
        $self->{queued} = 1;
    }

    warn "queue $file";

    $self->scan_file($file);
}

=head2 info

Return various information that's given by the B<HELP>
command. Returns a key-value list with the following keys and their
values after being lower-cased:

=over 4

=item fpscand

The version of fpscand.

=item engine

The version of the F-Prot engine fpscand is using.

=item protocol

The protocol this libary is speaking to fpscand.

=item signatures

The ID of the antivirus signature loaded into fpscand. This is in the
format:

   YYYYMMDDHHMM[MD5]

Where B<MD5> is a 32-bit MD5 sum of the signature file (the square
brackets are not present in the string).

=item uptime

The uptime of the fpscand.

=back

=cut

{ my $warned; # only warn about protocol mismatch once
sub info
{
    my ($self) = @_;
    my ($res, %ret);

    $res = $self->command("help\n");

    # The daemon will send `Send HELP COMMAND ...' as its second
    # output line. This needs to be thrown away so that the next thing
    # that does ->getline won't end up with it exepecting something else.
    #
    # It might be better to change the design of this module to use
    # non-blocking IO and make ->command greedy.
    $self->socket->getline;

    @ret{qw< fpscand engine protocol signature uptime >} = $res =~ $FPSCAND_HELP_FORMAT;

    if (not $warned and $ret{protocol} > $FPSCAND_PROTOCOL) {
        warn sprintf "fpscand is using protocol version %s but %s expects " .
                     "expects version %s. You should upgrade to avoid any problems",
                     $ret{protocol}, __PACKAGE__, $FPSCAND_PROTOCOL;
        # Don't warn again
        $warned = 1;
    }

    %ret;
}
}

=head2 quit

Inform the daemon that we are going away and close the connection to
it, this will be automatically called (via C<DESTROY>) when the object
goes out of scope.

=cut

*DESTROY = \&quit;

sub quit
{
    my ($self) = @_;

    if ($self->{socket}) {
        # Notify the daemon that we're going away and close the socket
        $self->{socket}->print("quit\n");
        undef $self->{socket};
    }
}

=head1 INTERNAL METHODS

These methods should not be used by normal users of this class but
they might be overridden if the module was sub-classed,

=cut

=head2 command

Send a command on the current socket and return a C<chomp>-ed
response.

=cut

sub command
{
    my ($self, $cmd) = @_;

    my $socket = $self->socket;

    $socket->print($cmd);

    chomp(my $res = $socket->getline);

    $res;
}

=head2 socket

Get a L<IO::Socket::INET> TCP socket to host/port given to
L</new>. Takes care of opening one if there isn't one already or if
the previous socket has been closed for some reason.

=cut

sub socket
{
    my ($self) = @_;

    my $socket = $self->{socket};

    unless (defined $socket) {
        # We don't have a socket or our socket died, either way open a
        # new one
        $socket = IO::Socket::INET->new(
            Proto => "tcp",
            PeerAddr => $self->{host},
            PeerPort => $self->{port},
        );
    }

    # Couldn't establish a socket with the daemon, croak
    $croak->("Failed to open connection to $self->{host}:$self->{port}: $!")
        unless defined $socket;

    return $self->{socket} = $socket;
}

sub parse_line
{
    my ($self, $line) = @_;

    my @m;
    return @m if @m = $line =~ $FPSCAND_FILE_FORMAT_ARCHIVE;
    return @m if @m = $line =~ $FPSCAND_FILE_FORMAT_FILE;
    return @m if @m = $line =~ $FPSCAND_FILE_FORMAT_ERR;
    die "Failed to parse: '$line'";
}

1;

__END__

# Note: copied from fpcmd-ng/exitcodes.txt

=head1 Return codes

These are the return codes the scanning fuctions return, the code is a
bitfield.

=head2 Infection codes (bits 1-2)

=over

=item 1

At least one virus-infected object was found (and remains)

=item 2

At least one suspicious (heuristic match) object was found (and remains)

=item 3

Both 1 and 2.

=back

Testing for infections could thus be done with C<<$exitcode & 0x03>>.

=head2 Error/unsure code (bits 3-6)

These may be combined with infection codes.

=over

=item 4

Interrupted by user. (SIGINT, SIGBREAK)

=item 8

Scan restriction caused scan to skip files (maxdepth directories,
maxdepth archives, exclusion list, etc)

=item 16

Platform error (out of memory, real I/O errors, insufficient file
permission etc.)

=item 32

Internal engine error (whatever the engine fails at).

=item 16+4(20)

Initilization error, i.e. every failure that occurs before any
scanning starts.

=item 32+16(48)

Crashed (handle_gpf).

=back

=head2 Clean codes (bits 7-8)

=over

=item 64

Clean as far as we know, although at least one object was not scanned
(encrypted file, unsupported/unknown compression method, corrupted or
invalid file).

=item 128

At least one object was disinfected (clean now).

=item 192

same as 64 + 128, i.e. something skipped, something
disinfected. Overall: Clean

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@f-prot.com>

=head1 LICENSE

Copyright 2007-2008 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
