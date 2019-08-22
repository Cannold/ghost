#!/usr/bin/env perl
use strict;
use warnings qw(FATAL utf8);   # encoding errors raise exceptions
# use utf8;                    # source is in UTF-8
use open qw(:utf8 :std);       # default open mode, `backticks`, and std{in,out,err} are in UTF-8

use Function::Parameters qw( :strict );
use File::Slurp;
use YAML::XS;
use Encode qw( decode_utf8 );
use Data::Dumper;
use Cpanel::JSON::XS;;
use Data::Validate::URI qw( is_uri );
use POSIX qw( strftime );
use Time::Piece;

# $YAML::XS::UseCode=1;

my $yaml = read_file($ARGV[0]);
my @array = Load $yaml;

my %tag;
foreach my $item (@array) {
    next unless
        ref $item eq 'ruby/object:Tag'
        && $item->{attributes}{taggable_type} eq 'CanpubArticle'
        && $item->{attributes}{phrase} ne 'sidebar'
        && $item->{attributes}{slug} ne 'in-the-media1';

    push @{$tag{$item->{attributes}{taggable_id}}},
         $item->{attributes}{slug};
}

my %types;
map { $types{ref $_}++ } @array;

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

# asset_lookup hash will have key-value as <guid/filename> => <path>
my %asset_lookup;

# tag lookup will have key-value as <post ID> => <array of tags>
my %tag_lookup;

for my $item (@array) {

    my $item_ref = ref($item);
    if ($item_ref =~ /^ruby\/object\:(CanpubArticle|Page)$/) {
        my $post = extract_article_info($item);
        push @content_ref, $post;
    }
    elsif ($item_ref eq "ruby/object:Asset") {
        my $path = "/content/images/$item->{attributes}{guid}/$item->{attributes}{filename}";
        my $key = "$item->{attributes}{guid}/$item->{attributes}{filename}";
        $asset_lookup{ $key } = $path;

    }
    elsif ($item_ref eq "ruby/object:Tag") {
        extract_tag_info($item);
    }
}

# add tags for each posts
for my $item (@content_ref) {
    my $id = delete $item->{id};
    $item->{tags} = $tag_lookup{ $id } if exists $tag_lookup{ $id };
}


# encoded and returned
my $encoded_content = Cpanel::JSON::XS->new->allow_blessed->encode(\@content_ref);
print $encoded_content;

fun extract_article_info($item) {

    my $created = $item->{attributes}{created_on} // $item->{attributes}{created_at};
    $created =~ s/(\d{4}-\d{2}-\d{2}).*$/$1/;

    my $published = $item->{attributes}{publish_on} || $created;
    if ($published !~ m/\d{4}-\d{2}-\d{2}/) {
        # e.g. May 01, 2019
        my $time = Time::Piece->strptime($published, "%B %d, %Y");
        $published = $time->strftime("%Y-%m-%d");
    }

    my $content = decode_utf8($item->{attributes}{content_markup});
    $content =~ s/^\s*|\s*$//g; # trailing space

    my @matches = $content =~ m/\/static\/files\/assets\/(.*?)"/g;
    # replace /static/files/assets/{id}/{filename} with /content/images/{id}/{filenmae}
    for my $match (@matches) {
        $content =~ s/\/static\/files\/assets\/.*?"/$asset_lookup{$match}"/g;
    }
    # remove mimetypes img which cause weird error in display
    $content =~ s/<img.*?mimetypes.*?\/>//g;

    my $post = {
        #tags          => defined $item->{attributes}{categories}
        #                ? [ $item->{attributes}{categories} ]
        #                : [],
        id            => $item->{attributes}{id},
        published_at  => $published ? $published . "T00:00:00.000Z" : undef,
        created_at    => $created ? $created . "T00:00:00.000Z" : undef,
        title         => decode_utf8($item->{attributes}{title}),
        html          => $content,
        status        => "draft",
        slug          => $item->{attributes}{slug},
    };

    if ($item->{attributes}{link} && is_uri($item->{attributes}{link})) {
        $post->{canonical_url} = $item->{attributes}{link};
    }
    if ( $item->{attributes}{excerpt} ) {
        my $excerpt = decode_utf8($item->{attributes}{excerpt});
        $excerpt =~ s/\r\n/ /gs;
        $post->{excerpt} = $excerpt;
    }
    else {
        my @splits = split " ", $item->{attributes}{content};
        $post->{excerpt} = join " ", @splits[0 .. 99];
    }
    return $post;

}

fun extract_tag_info($item) {
    my $val = $item->{attributes}{slug};
    my $key = $item->{attributes}{taggable_id};

    next if $val =~ m/^(books|sidebar)$/;
    if (exists $tag_lookup{ $key }) {
        push @{ $tag_lookup{ $key } }, $val;
    }
    else {
        $tag_lookup{ $key } = [ $val ];
    }
}
