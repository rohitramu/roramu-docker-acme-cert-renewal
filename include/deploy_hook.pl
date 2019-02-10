#!/usr/bin/perl -w

use strict;

$| = 1; # No buffering

my $CHALLENGE_DOMAIN = $ARGV[0];
my $KEYFILE = $ARGV[1];
my $CERTFILE = $ARGV[2];
my $FULLCHAINFILE = $ARGV[3];
my $CHAINFILE = $ARGV[4];
my $TIMESTAMP = $ARGV[5];

print "Using default (no-op) deploy-hook!\n";
print "\n";
print "Domain: $CHALLENGE_DOMAIN\n";
print "Key file: $KEYFILE\n";
print "Certificate file: $CERTFILE\n";
print "Full chain certificate file: $FULLCHAINFILE\n";
print "Chain file: $CHAINFILE\n";
print "Timestamp: $TIMESTAMP\n";