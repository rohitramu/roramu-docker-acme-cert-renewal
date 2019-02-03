#!/usr/bin/perl -w

# Based on https://github.com/lukas2511/dehydrated/wiki/example-dns-01-nsupdate-script

use strict;

$|=1;                   # No buffering

my $HOOK=$ARGV[0];
if ($HOOK eq "startup_hook") {
    print "Starting dehydrated...";
} elsif ($HOOK eq "deploy_challenge") {
    my $CHALLENGE_DOMAIN=$ARGV[1];
    my $CHALLENGE_TOKEN=$ARGV[3];
    my $CHALLENGE_SUBDOMAIN=$ENV{'CERT_CHALLENGE_SUBDOMAIN'};

    print "Adding the following to the zone definition of $CHALLENGE_DOMAIN:\n";
    print "$CHALLENGE_SUBDOMAIN.$CHALLENGE_DOMAIN. IN TXT \"$CHALLENGE_TOKEN\"\n";

    # Add the token to the file that the PowerDNS pipe backend will read from
    my $filename = $ENV{'CERT_CHALLENGES_FILE'};
    open(my $fh, '>>', $filename) or die "Could not open file '$filename' $!";
    print $fh "$CHALLENGE_TOKEN\n";
    close $fh;

    #my $tmp = <STDIN>;
    print "\n";
} elsif ($HOOK eq "clean_challenge") {
    my $CHALLENGE_DOMAIN=$ARGV[1];
    my $CHALLENGE_TOKEN=$ARGV[3];
    my $CHALLENGE_SUBDOMAIN=$ENV{'CERT_CHALLENGE_SUBDOMAIN'};

    print "Removing the following from the zone definition of $CHALLENGE_DOMAIN:\n";
    print "$CHALLENGE_SUBDOMAIN.$CHALLENGE_DOMAIN. IN TXT \"$CHALLENGE_TOKEN\"\n";

    # Remove the token from the file that the PowerDNS pipe backend reads from
    my $filename = $ENV{'CERT_CHALLENGES_FILE'};
    # Read the lines in the file
    open(my $fhRead, '<', $filename) or die "Could not open file '$filename' $!";
    my @lines = <$fhRead>;
    chomp @lines;
    close $fhRead;
    # Write all the lines that don't contain the token to be removed
    open(my $fhWrite, '>', $filename) or die "Could not open file '$filename' $!";
    foreach (@lines) {
        if ($_ ne $CHALLENGE_TOKEN) {
            print {$fhWrite} "$_\n";
        }
    }
    close $fhWrite;

    #my $tmp = <STDIN>;
    print "\n";
} elsif ($HOOK eq "deploy_cert") {
    my $CHALLENGE_DOMAIN=$ARGV[1];
    my $KEYFILE=$ARGV[2];
    my $CERTFILE=$ARGV[3];
    my $FULLCHAINFILE=$ARGV[4];
    my $CHAINFILE=$ARGV[5];
    my $TIMESTAMP=$ARGV[6];

    my $SECRET_NAME=$ENV{'SECRET_NAME'};
    my $SECRET_NAMESPACE=$ENV{'SECRET_NAMESPACE'};

    # Create the Kubernetes secret so services can use the cert
    print "Deploying cert as secret '$SECRET_NAME' to Kubernetes namespace '$SECRET_NAMESPACE'\n";
    system("kubectl create secret tls $SECRET_NAME --key $KEYFILE --crt $FULLCHAINFILE --dry-run -o yaml | kubectl apply -f -");
    print "\n";
} elsif ($HOOK eq "unchanged_cert") {
    my $CHALLENGE_DOMAIN=$ARGV[1];

    print "Cert unchanged for domain: $CHALLENGE_DOMAIN\n";
    print "\n";
} else {
    print "Unknown hook \"$HOOK\"\n";
    print "\n";
}