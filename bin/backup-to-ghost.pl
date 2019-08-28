#!/usr/bin/env perl
use strict;
use warnings qw(FATAL utf8);   # encoding errors raise exceptions
# use utf8;                    # source is in UTF-8
use open qw(:utf8 :std);       # default open mode, `backticks`, and std{in,out,err} are in UTF-8

use Function::Parameters qw( :strict );
use File::Slurp;
use YAML::XS;
use Encode qw( decode_utf8 );
use Cpanel::JSON::XS;;
use POSIX qw( strftime );
use Time::Piece;

# $YAML::XS::UseCode=1;

my $yaml = read_file($ARGV[0]);
my @array = Load $yaml;

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

# tag lookup will have key-value as <post ID> => <array of tags>
my %citation_lookup;

my $event_tag = "Events";

for my $item (@array) {

    my $item_ref = ref($item);
    if ($item_ref =~ /^ruby\/object\:(CanpubArticle|Page)$/) {
        my $post = extract_article_info($item);
        push @content_ref, $post;
    }
    elsif ($item_ref eq "ruby/object:EvtEvent") {
        my $post = extract_event_info($item);
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
    elsif ($item_ref eq "ruby/object:CanpubCitation") {
        extract_publication_info($item);
    }
}

# add tags for each posts
for my $item (@content_ref) {
    my $id = delete $item->{id};

    # EvtEvent doesn't need citation and multiple tags
    next if defined $item->{tags} && $item->{tags}[0] eq $event_tag;

    $item->{tags} = $tag_lookup{ $id } if exists $tag_lookup{ $id };
    if (exists $citation_lookup{ $id }) {
        $item->{html} .= q(
            <div class="citation">
                <h4>Publication history</h4>
            )
            . join(" ", @{$citation_lookup{ $id }})
            . q( </div> );
    }
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
        id            => $item->{attributes}{id},
        published_at  => $published ? $published . "T00:00:00.000Z" : undef,
        created_at    => $created ? $created . "T00:00:00.000Z" : undef,
        title         => decode_utf8($item->{attributes}{title}),
        html          => $content,
        status        => "draft",
        slug          => $item->{attributes}{slug},
    };

    if ($item->{attributes}{link}) {
        $post->{html} .= qq( <a href=\"$item->{attributes}{link}\">$item->{attributes}{link}</a> );
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

fun extract_event_info($item) {
    # Event has similar info as Page/Post
    # it only has different tag and title format
    my $post = extract_article_info($item);
    $post->{tags} = [ $event_tag ];

    # event has start date - end date presenting in three forms:
    # - in specifc timetable (2016-11-21 12:50:00 - 2016-11-21 13:50:00 => 12:50pm - 1:50pm, 21 Nov 2016)
    # - full day (2016-10-20 00:00:00 - 2016-10-20 00:00:00 => 04 Oct 2016)
    # - multiple day (2016-09-20 00:00:00 - 2016-09-22 00:00:00 => 20 Sep 2016 - 22 Sep 2016)
    # - multiple day with specific time table (2016-09-20 14:00:00 - 2016-09-22 17:00:00 => 20 Sep 2016 14:00 - 22 Sep 2016 17:00)

    my $regex = qr/^(\d{4}-\d{2}-\d{2})\s(\d{2}:\d{2})/;
    my ($start_date, $start_time) = $item->{attributes}{start_date} =~ m/$regex/;
    my ($end_date, $end_time) = $item->{attributes}{end_date} // $item->{attributes}{start_date} =~ m/$regex/;

    my @dates = $start_date eq $end_date ? ( $start_date ) : ( $start_date, $end_date );
    my @times = $start_time eq $end_time ? ( $start_time ) : ( $start_time, $end_time );

    my @format_dates;
    for my $item (@dates) {
        my $date = Time::Piece->strptime($item, "%Y-%m-%d");
        push @format_dates, $date->strftime("%d %b %Y");
    }

    my @format_times;
    for my $item (@times) {
        my $time = Time::Piece->strptime($item, "%H:%M:%S");
        push @format_times, $time->strftime("%I:%M %p");
    }

    my $title;

    if (@format_dates == 2 && @format_times == 2) {
        $title = "$format_dates[0] $format_times[0] - $format_dates[1] $format_times[1]: ";
    }
    elsif (@format_dates == 2 && @format_times == 1) {
        $title = join(" - ", @format_dates) . ": ";
    }
    elsif (@format_dates == 1 && @format_times == 2) {
        $title = join(" - ", @format_times) . ", $format_dates[0]: ";
    }
    elsif (@format_dates == 1 && @format_times == 1) {
        $title = "$format_dates[0]: ";
    }
    $post->{title} = $title . $post->{title};
    return $post;
}

fun extract_tag_info($item) {
    my $val = $item->{attributes}{slug};
    my $key = $item->{attributes}{taggable_id};

    # skip these tags
    # event tag will be added to EvtEvent object directly
    next if $val =~ m/^(books|sidebar|event)$/;

    my %rename_hash = (
        "in-the-media"  => "In the media",
        "in-the-media1" => "In the media",
        "research"      => "Research",
        "writings"      => "Writings",
    );
    $val = $rename_hash{ $val };

    if (exists $tag_lookup{ $key }) {
        push @{ $tag_lookup{ $key } }, $val;
    }
    else {
        $tag_lookup{ $key } = [ $val ];
    }
}

fun extract_publication_info($item) {
    my $key = $item->{attributes}{article_id};
    my $val = qq(
        <blockquote>
            $item->{attributes}{headline}
            <em>$item->{attributes}{publication}</em>
            <br>$item->{attributes}{date}<br>
            <a href=\"$item->{attributes}{link}\">$item->{attributes}{link}</a>
        </blockquote>
    );

    if (exists $citation_lookup{ $key }) {
        push @{ $citation_lookup{ $key } }, $val;
    }
    else {
        $citation_lookup{ $key } = [ $val ];
    }
}
