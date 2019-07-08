#!/usr/bin/env perl

use 5.24.0;
use strict;
use warnings;

use URI;
use DBI;
use Data::Dumper;

my $sth;
my $uri = URI->new($ENV{DB_URI});
my $dbh = DBI->connect($uri->dbi_dsn, $uri->user, $uri->password, { RaiseError => 1, AutoCommit => 0 });

my $target = $ARGV[0];
$sth = $dbh->prepare(qq(
    SELECT a1.id AS api_id, a1.secret AS secret, a1.type AS api_type
    FROM api_keys AS a1
    JOIN integrations AS a2 ON a1.integration_id = a2.id
    WHERE a2.name = ?
));
$sth->execute($ENV{SERVICE_NAME});
my $key_ref = $sth->fetchall_hashref("api_type");
#print Dumper($key_ref);
print "$key_ref->{$target}{api_id}:$key_ref->{$target}{secret}";

$dbh->disconnect();
