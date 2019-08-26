#!/usr/bin/env perl

use 5.24.0;
use strict;
use warnings;

use DBI;
use Data::UUID;
use Function::Parameters qw(:strict);
use URI;

my $ug = Data::UUID->new;

my $uri = URI->new($ENV{DB_URI});
my $database = DBI->connect($uri->dbi_dsn, $uri->user, $uri->password, { RaiseError => 1, AutoCommit => 1 });
setup_api($database);
setup_admin_login($database);
$database->disconnect();
say "Done setup";

exit 0;

# instead of going to {hostname}/ghost and setting up an admin account
# this will just directly make a custom integration for us
# so we can use Admin API and Content API to work with the export process

# this will make 3 entries
# - an entry in INTEGRATION table
# - an entry in API_KEYS table for Admin API
# - an entry in API_KEYS table for Content API
fun setup_api($dbh) {

    my $sth;
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

    my $content_secret = $ENV{CONTENT_SECRET};
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

    my $admin_api_id = $ENV{ADMIN_API_ID};
    my $admin_secret = $ENV{ADMIN_SECRET};
    $sth = $dbh->prepare(qq(
        INSERT INTO api_keys
            (id, type, secret, role_id, integration_id, created_at, created_by)
        VALUES
            (?, ?, ?, ?, ?, NOW(), 1)
    ));
    $sth->execute($admin_api_id, "admin", $admin_secret, $role_id, $integration_id);
}

# setup a login account
# Email: test01@mail.com
# Password: long_pass_01
fun setup_admin_login($dbh) {

    my $sth;

    $sth = $dbh->prepare(qq(
        SELECT id FROM roles WHERE name = ?
    ));
    $sth->execute("Owner");
    my $ref = $sth->fetchall_arrayref({});
    my $blog_owner_id = $ref->[0]->{id};

    # password = long_pass_01
    my $email    = $ENV{LOGIN_EMAIL};
    my $password = $ENV{LOGIN_PASSWORD};
    my $user_id  = 100;
    $sth = $dbh->prepare(qq(
        INSERT INTO users
            (id, name, slug, password, email, created_at, created_by)
        VALUES
            (?, ?, ?, ?, ?, NOW(), NOW())
    ));
    $sth->execute($user_id, "Blog owner Ghost", "blog-owner-ghost", $password, $email);

    $sth = $dbh->prepare(qq(
        INSERT INTO roles_users
            (id, role_id, user_id)
        VALUES
            (?, ?, ?)
    ));
    $sth->execute("5d6338a9bfcf010001f3a101", $blog_owner_id, $user_id);
}

fun generate_id($length = undef) {
    my $id = $ug->create_str();
    $id =~ s/\-//g;

    return ($length ? substr($id, 0, $length) : $id);
}
