#!/usr/bin/env perl
use strict;
use warnings qw(FATAL utf8);   # encoding errors raise exceptions
# use utf8;                    # source is in UTF-8
use open qw(:utf8 :std);       # default open mode, `backticks`, and std{in,out,err} are in UTF-8

use File::Slurp;
use YAML::XS;
use Encode qw( decode_utf8 );
use Data::Dumper;

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
print Dumper \%types;

foreach my $item (@array) {

    next unless ref $item eq 'ruby/object:CanpubArticle';

    my $created = $item->{attributes}{created_on};
    $created =~ s/(\d\d\d\d-\d\d-\d\d)/$1/;
    my $published = $item->{attributes}{publish_on} || $created;

    my $post = {
        categories => defined $tag{$item->{attributes}{id}}
                        ? join " ", @{$tag{$item->{attributes}{id}}}
                        : undef,
        assets     => $item->{assets},
        link       => $item->{attributes}{link},
        published  => $published,
        title      => $item->{attributes}{title},
        # _blueprint => $item->{attributes},
    };

    if ( $item->{attributes}{excerpt} ) {
        my $excerpt = decode_utf8($item->{attributes}{excerpt});
        $excerpt =~ s/\r\n/ /gs;
        $post->{excerpt} = $excerpt;
    }

    my @post;
    push @post, $post;

    open(my $fh, '>:raw', 'posts/' . $published . '-' . $item->{attributes}{slug} . '.md');

    print $fh Dump @post;

    close $fh;

    open(my $fh, '>>', 'posts/' . $published . '-' . $item->{attributes}{slug} . '.md');

    print $fh "---\n";

    my $content = decode_utf8($item->{attributes}{content});
    $content =~ s/\r//sg;
    print $fh $content;

}
