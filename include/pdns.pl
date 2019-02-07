#!/usr/bin/perl -w

use strict;

$|=1; # No buffering

my $line=<>;
chomp($line);

unless($line eq "HELO\t1") {
    print "FAIL\n";
    print STDERR "Received '$line'\n";
    <>;
    exit;
}
print "OK\tBackend firing up\n"; # Print our banner

my $AUTH_DOMAIN=$ENV{'AUTH_DOMAIN'};
my $CERT_CHALLENGES_FILE=$ENV{'CERT_CHALLENGES_FILE'};
my $CERT_CHALLENGE_DOMAIN="$ENV{'CERT_CHALLENGE_SUBDOMAIN'}.$AUTH_DOMAIN";
my $MATCH_AUTH_DOMAIN="/^(.*\.)?$AUTH_DOMAIN$/gm";

while(<>)
{
    print STDERR "$$ Received: $_";
    chomp();
    my @arr=split(/\t/);
    if(@arr<6) {
        print "LOG\tPowerDNS sent unparseable line\n";
        print "FAIL\n";
        next;
    }

    # NOTE: The qname is what PowerDNS asks the backend. It need not be what the internet asked PowerDNS!
    my ($type,$qname,$qclass,$qtype,$id,$ip)=split(/\t/);

    if(($qtype eq "SOA" || $qtype eq "ANY") && $qname =~ $MATCH_AUTH_DOMAIN) {
        print STDERR "$$ Sent SOA records\n";

        print "DATA\t$qname\t$qclass\tSOA\t3600\t-1\t$AUTH_DOMAIN $AUTH_DOMAIN 2008080300 1800 3600 604800 3600\n";
    }
    if(($qtype eq "TXT" || $qtype eq "ANY") && $qname eq $CERT_CHALLENGE_DOMAIN) {
        print STDERR "$$ Sent TXT records\n";

        open(my $fh, '<', $CERT_CHALLENGES_FILE) or die "Could not open file '$CERT_CHALLENGES_FILE' $!";
        my @CERT_CHALLENGE_TOKENS = <$fh>;
        close $fh;
        chomp @CERT_CHALLENGE_TOKENS;

        foreach (@CERT_CHALLENGE_TOKENS) {
            print "DATA\t$qname\t$qclass\tTXT\t1\t-1\t\"$_\"\n";
        }
    }


    print STDERR "$$ End of data\n";
    print "END\n";
}