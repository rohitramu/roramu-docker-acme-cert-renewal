#!/usr/bin/perl -w

# Based on https://github.com/lukas2511/dehydrated/wiki/example-dns-01-nsupdate-script

use strict;

$| = 1; # No buffering

my $HOOK = $ARGV[0];
if ($HOOK eq "startup_hook") {
    print "Starting dehydrated...\n";
    print "\n";
} elsif ($HOOK eq "deploy_challenge") {
    my $CHALLENGE_DOMAIN = $ARGV[1];
    my $CHALLENGE_TOKEN = $ARGV[3];
    my $CHALLENGE_SUBDOMAIN = $ENV{'CERT_CHALLENGE_SUBDOMAIN'};

    print "Adding the following to the zone definition of '$CHALLENGE_DOMAIN':\n";
    print "$CHALLENGE_SUBDOMAIN.$CHALLENGE_DOMAIN. IN TXT \"$CHALLENGE_TOKEN\"\n";

    # Add the token to the file that the PowerDNS pipe backend will read from
    my $filename = $ENV{'CERT_CHALLENGES_FILE'};
    open(my $fh, '>>', $filename) or die "Could not open file '$filename' $!";
    print $fh "$CHALLENGE_TOKEN\n";
    close $fh;

    # Wait here for user input if debug mode is turned on
    if ($ENV{'DEBUG'} eq "true") {
        print "Debug mode is on - press <enter> to continue...\n";
        my $tmp = <STDIN>;
    }

    print "\n";
} elsif ($HOOK eq "clean_challenge") {
    my $CHALLENGE_DOMAIN = $ARGV[1];
    my $CHALLENGE_TOKEN = $ARGV[3];
    my $CHALLENGE_SUBDOMAIN = $ENV{'CERT_CHALLENGE_SUBDOMAIN'};

    print "Removing the following from the zone definition of '$CHALLENGE_DOMAIN':\n";
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

    # Wait here for user input if debug mode is turned on
    if ($ENV{'DEBUG'} eq "true") {
        print "Debug mode is on - press <enter> to continue...\n";
        my $tmp = <STDIN>;
    }

    print "\n";
} elsif ($HOOK eq "deploy_cert") {
    my $CHALLENGE_DOMAIN = $ARGV[1];
    my $KEYFILE = $ARGV[2];
    my $CERTFILE = $ARGV[3];
    my $FULLCHAINFILE = $ARGV[4];
    my $CHAINFILE = $ARGV[5];
    my $TIMESTAMP = $ARGV[6];

    my $DEPLOY_HOOK = $ENV{'DEPLOY_HOOK'};
    my $DEPLOY_LOG = $ENV{'DEPLOY_LOG'};
    my $DEPLOY_LOG_ERR = $ENV{'DEPLOY_LOG_ERR'};

    print "Certificate can be deployed...\n";
    print "Deploy hook: $DEPLOY_HOOK\n";
    print "Domain: $CHALLENGE_DOMAIN\n";
    print "Key file: $KEYFILE\n";
    print "Certificate file: $CERTFILE\n";
    print "Full chain certificate file: $FULLCHAINFILE\n";
    print "Chain file: $CHAINFILE\n";
    print "Timestamp: $TIMESTAMP\n";

    # Call the deploy-hook
    print "\n";
    print "== Start deploy-hook ==\n";
    system("echo Starting deploy-hook... > $DEPLOY_LOG");
    if (system("$DEPLOY_HOOK \"$CHALLENGE_DOMAIN\" \"$KEYFILE\" \"$CERTFILE\" \"$FULLCHAINFILE\" \"$CHAINFILE\" \"$TIMESTAMP\" | tee \"$DEPLOY_LOG\"") != 0) {
        # If the deploy hook failed, rename the file to indicate failure
        system("mv \"$DEPLOY_LOG\" \"$DEPLOY_LOG_ERR\"");
    }
    print "== End deploy-hook ==\n";
    print "\n";

    print "\n";
} elsif ($HOOK eq "exit_hook") {
    print "Successfully obtained certificate\n";
    print "\n";
} elsif ($HOOK eq "unchanged_cert") {
    my $CHALLENGE_DOMAIN = $ARGV[1];

    print "Existing certificate is still valid for domain: $CHALLENGE_DOMAIN\n";
    print "\n";
} elsif ($HOOK eq "invalid_challenge") {
    my $ALTERNATIVE_NAME = $ARGV[1];
    my $RESULT = $ARGV[2];

    print "Invalid challenge for alternative name: $ALTERNATIVE_NAME\n";
    print "Result:\n$RESULT\n";
    print "\n";
} else {
    print "Unknown hook \"$HOOK\"\n";
    print "\n";
}