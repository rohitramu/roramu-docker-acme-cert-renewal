#!/usr/bin/perl -w

use strict;
use File::Find;


$|=1;					# no buffering

my $line=<>;
chomp($line);

unless($line eq "HELO\t1") {
	print "FAIL\n";
	print STDERR "Received '$line'\n";
	<>;
	exit;
}
print "OK	Sample backend firing up\n";	# print our banner

my $AUTH_DOMAIN=$ENV{'AUTH_DOMAIN'};
my $CERT_CHALLENGE_DIR=$ENV{'CERT_CHALLENGE_DIR'};
my $CERT_CHALLENGE_DOMAIN="$ENV{'CERT_CHALLENGE_SUBDOMAIN'}.$AUTH_DOMAIN";
my $MATCH_AUTH_DOMAIN=/^(.*\.)?$AUTH_DOMAIN$/gm;

while(<>)
{
	print STDERR "$$ Received: $_";
	chomp();
	my @arr=split(/\t/);
	if(@arr<6) {
		print "LOG	PowerDNS sent unparseable line\n";
		print "FAIL\n";
		next;
	}

	# note! the qname is what PowerDNS asks the backend. It need not be what the internet asked PowerDNS!
	my ($type,$qname,$qclass,$qtype,$id,$ip)=split(/\t/);

	if(($qtype eq "SOA" || $qtype eq "ANY") && $qname =~ $MATCH_AUTH_DOMAIN) {
		print STDERR "$$ Sent SOA records\n";
		print "DATA	$qname	$qclass	SOA	3600	-1	$AUTH_DOMAIN $AUTH_DOMAIN 2008080300 1800 3600 604800 3600\n";
	}
	if(($qtype eq "TXT" || $qtype eq "ANY") && $qname eq $CERT_CHALLENGE_DOMAIN) {
		print STDERR "$$ Sent TXT records\n";
        find(
            sub {
                print "DATA	$qname	$qclass	TXT	1	-1	\"$_\"\n" if -f;
            },
            $CERT_CHALLENGE_DIR
        );
	}


	print STDERR "$$ End of data\n";
	print "END\n";
}