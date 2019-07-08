#!/usr/bin/env perl
use strict;
use warnings qw(FATAL utf8);   # encoding errors raise exceptions
# use utf8;                    # source is in UTF-8
use open qw(:utf8 :std);       # default open mode, `backticks`, and std{in,out,err} are in UTF-8

use File::Slurp;
use YAML::XS;
use Data::Structure::Util qw( unbless );
use Encode qw( decode_utf8 );
use Data::Dumper;
use Cpanel::JSON::XS;;

# $YAML::XS::UseCode=1;

my $yaml = read_file('data/backup.yml');
my @array = Load $yaml;

my %tag;
foreach my $item (@array) {
    next unless
        ref $item eq 'ruby/object:Tag'
        && $item->{attributes}{taggable_type} eq 'CanpubArticle'
        && $item->{attributes}{phrase} ne 'sidebar'
        && $item->{attributes}{slug} ne 'in-the-media1';

    #if (exists $tag{$item->{attributes}{taggable_id}}) {
    #    warn Dumper $tag{$item->{attributes}{taggable_id}};
    #    warn Dumper $item;
    #}

    push @{$tag{$item->{attributes}{taggable_id}}},
         $item->{attributes}{slug};
}

my %types;
map { $types{ref $_}++ } @array;
#print Dumper \%types;

# posts is an array, so we can prepare everythin
# and dump it in the array and make one big POST
#{
#    "posts": [{
#        "title": "My test post",
#        "tags": [{"name": "my tag", "description": "a very useful tag"}, {"name": "#hidden"}],
#        "authors": [{"id": "5c739b7c8a59a6c8ddc164a1"}, {"id": "5c739b7c8a59a6c8ddc162c5"}, {"id": "5c739b7c8a59a6c8ddc167d9"}]
#    }]
#}

my @content_ref;
foreach my $item (@array) {

    next unless ref $item eq 'ruby/object:CanpubArticle';

    my $created = $item->{attributes}{created_on};
    $created =~ s/(\d\d\d\d-\d\d-\d\d)/$1/;
    my $published = $item->{attributes}{publish_on} || $created;

    my $content = decode_utf8($item->{attributes}{content_markup});
    $content =~ s/^\s*|\s*$//g;

    my $post = {
        tags          => defined $item->{attributes}{categories}
                        ? [ $item->{attributes}{categories} ]
                        : [],
        canonical_url => $item->{attributes}{link},
        published_at  => $published . "T00:00:00.000Z",
        created_at    => $created . "T00:00:00.000Z",
        title         => $item->{attributes}{title},
        html          => $content,
        status        => "draft",
        slug          => $item->{attributes}{slug},
    };

    if ( $item->{attributes}{excerpt} ) {
        my $excerpt = decode_utf8($item->{attributes}{excerpt});
        $excerpt =~ s/\r\n/ /gs;
        $post->{excerpt} = $excerpt;
    }
    else {
        $post->{excerpt} = substr(decode_utf8($item->{attributes}{content_markup}), 0, 100);
    }

    push @content_ref, $post;
}

my $encoded_content = Cpanel::JSON::XS->new->allow_blessed->encode(\@content_ref);
print $encoded_content;

