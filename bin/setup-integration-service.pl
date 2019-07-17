#!/usr/bin/env perl

use 5.24.0;
use strict;
use warnings;

use DBI;
use Data::UUID;
use Data::Dumper;
use Function::Parameters qw(:strict);
use URI;

# instead of going to {hostname}/ghost and setting up an admin account
# this will just directly make a custom integration for us
# so we can use Admin API and Content API to work with the export process

# this will make 3 entries
# - an entry in INTEGRATION table
# - an entry in API_KEYS table for Admin API
# - an entry in API_KEYS table for Content API

my $ug = Data::UUID->new;

my $sth;
my $uri = URI->new($ENV{DB_URI});
my $dbh = DBI->connect($uri->dbi_dsn, $uri->user, $uri->password, { RaiseError => 1, AutoCommit => 1 });

# insert an entry for integrations
my $integration_id = generate_id(24);
$sth = $dbh->prepare(qq(
    INSERT INTO integrations 
        (id, type, name, slug, created_at, created_by)
    VALUES
        (?, ?, ?, ?, NOW(), 1)
));
$sth->execute($integration_id, "custom", $ENV{SERVICE_NAME}, $ENV{SERVICE_NAME});

# entry for content_api in api_keys table
my $content_api_id = generate_id(24);

my $content_secret = "08d0c8c76380072ed33e6b0109";
$sth = $dbh->prepare(qq(
    INSERT INTO api_keys
        (id, type, integration_id, secret, created_at, created_by)
    VALUES
        (?, ?, ?, ?, NOW(), 1)
));
$sth->execute($content_api_id, "content", $integration_id, $content_secret);

# entry for admin_api in api_keys table
$sth = $dbh->prepare(qq(
    SELECT id from roles WHERE name = ?
));
$sth->execute("Admin Integration");
my $ref = $sth->fetchall_arrayref({});
my $role_id = $ref->[0]->{id};

my $admin_api_id = "5d1e94e87708cd00017fee06";
my $admin_secret = "ec334cba073c3a1f0e2689ca5063beeee1bab3bded2901878edf4a43ffc5ff9d";;
$sth = $dbh->prepare(qq(
    INSERT INTO api_keys
        (id, type, secret, role_id, integration_id, created_at, created_by)
    VALUES
        (?, ?, ?, ?, ?, NOW(), 1)
));
$sth->execute($admin_api_id, "admin", $admin_secret, $role_id, $integration_id);

$dbh->disconnect();
say "Done setup";

exit 0;

fun generate_id($length = undef) {
    my $id = $ug->create_str();
    $id =~ s/\-//g;

    return ($length ? substr($id, 0, $length) : $id);
}
