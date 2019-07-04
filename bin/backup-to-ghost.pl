#!/usr/bin/env perl

use 5.24.0;
use strict;
use warnings qw(FATAL utf8);   # encoding errors raise exceptions
# use utf8;                    # source is in UTF-8
use open qw(:utf8 :std);       # default open mode, `backticks`, and std{in,out,err} are in UTF-8

use File::Slurp;
use Function::Parameters qw(:strict);
use URI;
use DBI;
use YAML::XS;
use Data::Structure::Util qw( unbless );
use Encode qw( decode_utf8 encode_utf8 );
use Data::Dumper;
use Crypt::JWT qw( encode_jwt );
use HTTP::Request;
use LWP::UserAgent;
use Cpanel::JSON::XS;

# $YAML::XS::UseCode=1;

my $yaml = read_file('data/backup.yml');
my @array = Load $yaml;
#print Dumper(\@array);

my $sth;
my $dbh = connect_db();

$sth = $dbh->prepare(qq(
    SELECT a1.id AS api_id, a1.secret AS secret, a1.type AS api_type
    FROM api_keys AS a1
    JOIN integrations AS a2 ON a1.integration_id = a2.id
    WHERE a2.name = ?
));
$sth->execute($ENV{SERVICE_NAME});
my $key_ref = $sth->fetchall_hashref("api_type");
print Dumper($key_ref);

$dbh->disconnect();

# issue at time 
my $iat = localtime;

# expire at (5 minute expiry time)
my $exp = $iat + 5 * 60;

my $token = encode_jwt(
    alg => "HS256",
    key => $key_ref->{admin}{secret},,
    extra_headers => {
        kid => $key_ref->{admin}{api_id},
        alg => "HS256",
        typ => "JWT"
    },
    payload => {
        iat => $iat,
        exp => $exp,
        aud => "/v2/admin/",
    },
);
my $header = ['Content-Type' => "application/json; charset=UTF-8",  Authorization => "Ghost $token" ];
my $body = {
    posts => [
        { title => "Hello world" },
    ],
};
my $url = "http://ghost:2368/ghost/api/v2/admin/posts/";
my $request = HTTP::Request->new("POST", $url, $header, encode_utf8(encode_json($body)));
my $ua = LWP::UserAgent->new;
my $response = $ua->request($request);
say Dumper($response);

fun connect_db() {
    my $uri = URI->new($ENV{DB_URI});
    my $dbh = DBI->connect($uri->dbi_dsn, $uri->user, $uri->password, { RaiseError => 1, AutoCommit => 1 });

    return $dbh;
}
