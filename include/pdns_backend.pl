#!/usr/bin/perl -w

# Based on https://raw.githubusercontent.com/PowerDNS/pdns/master/modules/pipebackend/backend.pl

use strict;

$|=1; # No buffering

my $line=<>;
chomp($line);

unless($line eq "HELO\t1") {
    print "FAIL\n";
    print STDERR "Received '$line'\n";
    <STDIN>;
    exit;
}
print "OK\tBackend firing up\n"; # Print our banner

# Get all arguments (and use lowercase for domain names to keep it case-insensitive)
my $AUTH_DOMAIN = lc $ENV{'AUTH_DOMAIN'};
my $CERT_CHALLENGES_FILE = $ENV{'CERT_CHALLENGES_FILE'};
my $CERT_CHALLENGE_DOMAIN = lc "$ENV{'CERT_CHALLENGE_SUBDOMAIN'}.$AUTH_DOMAIN";
my $MATCH_AUTH_DOMAIN = "^(.+\\.)?$AUTH_DOMAIN(\\.)?\$";

while(<STDIN>)
{
    print STDERR "$$ Received: $_";
    chomp();
    my @arr = split(/\t/);
    if (@arr < 6) {
        print "LOG\tPowerDNS sent unparseable line\n";
        print "FAIL\n";
        next;
    }

    # NOTE: The qname is what PowerDNS asks the backend. It need not be what the internet asked PowerDNS!
    my ($type,$qname,$qclass,$qtype,$id,$ip) = @arr;

    # Make the query case insensitive by converting the qname to lowercase and qtype to uppercase
    $qname = lc $qname;
    $qtype = uc $qtype;

    if (($qtype eq "SOA" || $qtype eq "ANY") && $qname =~ m/$MATCH_AUTH_DOMAIN/) {
        my $result = "DATA\t$qname\t$qclass\tSOA\t3600\t$id\t$AUTH_DOMAIN $AUTH_DOMAIN 2008080300 1800 3600 604800 3600\n";
        print STDERR "Returned: $result";
        print $result;
    }
    if (($qtype eq "NS" || $qtype eq "ANY") && $qname =~ m/$MATCH_AUTH_DOMAIN/) {
        my $result = "DATA\t$qname\t$qclass\tNS\t3600\t$id\t$AUTH_DOMAIN\n";
        print STDERR "Returned: $result";
        print $result;
    }
    if (($qtype eq "TXT" || $qtype eq "ANY") && $qname eq $CERT_CHALLENGE_DOMAIN) {
        open(my $fh, '<', $CERT_CHALLENGES_FILE) or die "Could not open file '$CERT_CHALLENGES_FILE' $!";
        my @CERT_CHALLENGE_TOKENS = <$fh>;
        close $fh;

        # Trim whitespace from each line
        chomp @CERT_CHALLENGE_TOKENS;
        # Remove empty lines
        @CERT_CHALLENGE_TOKENS = grep { $_ ne '' } @CERT_CHALLENGE_TOKENS;

        # Check if there are no challenge tokens
        if (scalar(@CERT_CHALLENGE_TOKENS) == 0) {
            # Send a standard response which indicates that no challenge tokens were found
            push @CERT_CHALLENGE_TOKENS, "NO_CHALLENGE_TOKENS_FOUND";
        }

        # Send the challenge tokens
        foreach (@CERT_CHALLENGE_TOKENS) {
            my $result = "DATA\t$qname\t$qclass\tTXT\t1\t$id\t$_\n";
            print STDERR "Returned: $result";
            print $result;
        }
    
    }

    print STDERR "$$ End of data\n";
    print "END\n";
}