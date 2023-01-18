#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Getopt::Long;
use Switch;
use Class::Struct;
use Data::Dumper;
use Text::Table;

use constant {
    "True"  => 1,
    "False" => 0,
};

sub HelpMessage {
    print("TODO....\n");
    exit(0);
}

sub log2 {
    my $n = shift;
    return log($n) / log(2);
}

# Arguments
my $vectorType       = "TP";    # TP, TF, TF-IDF
my $minWordFrequency = 1;
my $minWordLength    = 1;
my $norm             = False;
my $file             = "";

GetOptions(
    "file=s"        => \$file,
    "length|l=i"    => \$minWordLength,
    "frequency|f=i" => \$minWordFrequency,
    "type|t=s"      => \$vectorType,
    "norm|n=i"      => \$norm,
    "help|?"        => sub { HelpMessage() }
) or die("Error in command line arguments\n");

open my $open_file, $file or die "Could not open $file: $!";

my @class;
my @text;
my %dictionary;
while (<$open_file>) {
    chomp;
    s/#.*//;
    my $class;
    my $text;
    my @words;
    my @data;
    ( $class, $text ) = split( "\t", uc($_) );
    $text =~ s/<[^>]*>/ /gs;       # removes tags
    $text =~ s/\&[^;]*;/ /gs;      # removes entities
    $text =~ s/[\P{L}0-9_]/ /g;    # removes all non-letters
    @data = split( " ", $text );

    # check min length
    for (@data) {
        my $lenWord = length($_);
        if ( $lenWord >= $minWordLength ) {
            push( @words, $_ );
            $dictionary{$_}++;
        }
    }
    my $sizeOfWord = @words;
    if ( $sizeOfWord != 0 ) {
        push( @class, $class );
        push( @text,  \@words );
    }
    else {
        push( @class, $class );
        @words = ();
        push( @text, \@words );
    }

}
close $open_file;

my %docFreq;
foreach my $word ( keys(%dictionary) ) {
    foreach my $tmp (@text) {
        if ( grep( /^$word$/, @$tmp ) ) {
            $docFreq{$word}++;
        }
    }
}

# delete short words
if ( $minWordFrequency > 1 ) {
    for ( keys(%dictionary) ) {
        if ( $dictionary{$_} < $minWordFrequency ) {
            delete( $dictionary{$_} );
        }
    }

    # deleting words from text
    for my $text (@text) {
        for my $i ( reverse 0 .. $#$text ) {
            my $tmp = $text->[$i];
            if ( !exists $dictionary{$tmp} ) {
                splice( @$text, $i, 1 );
            }
        }
    }
}

# create array of hashs text words
my @hashWords;
foreach my $doc (@text) {
    my %words;
    foreach my $word (@$doc) {
        $words{$word}++;
    }
    push( @hashWords, \%words );
}

my @outputDoc = ();
my $counter   = 0;
for my $hash (@hashWords) {
    my %output;
    foreach my $texts ( keys(%dictionary) ) {
        foreach my $word ($texts) {
            $output{$word} = 0;
        }
    }
    for my $word ( keys(%$hash) ) {
        if ( $vectorType eq "TP" ) {
            $output{$word} = 1;
        }
        elsif ( $vectorType eq "TF" ) {
            $output{$word} = %$hash{$word};
        }
        elsif ( $vectorType eq "TF-IDF" ) {
            my $doc = @class;
            $output{$word} = sprintf( '%.3f',
                ( %$hash{$word} * log2( $doc / $docFreq{$word} ) ) );
        }

    }

    if ( $norm == True ) {
        for my $word ( sort keys(%$hash) ) {
            if ( $vectorType eq "TF" ) {
                if ( $norm == True ) {
                    $output{$word} = sprintf( '%.3f',
                        ( %$hash{$word} / eval join '+', values %$hash ) );
                }
            }
            elsif ( $vectorType eq "TF-IDF" ) {
                if ( $norm == True ) {
                    $output{$word} = sprintf( '%.3f',
                        ( %$hash{$word} / eval join '+', values %$hash ) );
                }
            }
        }
    }

    my @tmp = ();
    for my $word ( sort keys(%dictionary) ) {
        my $val = $output{$word};
        push( @tmp, $val );
    }
    push( @tmp,       $class[$counter] );
    push( @outputDoc, \@tmp );
    $counter++;
}

my @tableHeader;
foreach ( sort keys(%dictionary) ) {
    push( @tableHeader, $_ );
}
push( @tableHeader, "_CLASS_" );

my $table = Text::Table->new(@tableHeader);
$table->load(@outputDoc);
print($table);
exit(0);
