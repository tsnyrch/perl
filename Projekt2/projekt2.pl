#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Getopt::Long;
use Text::Table;

# Arguments
my $argBeta = 0.5;
my $argIteration = 10;
my $argCalibration = "None";
my $argA = 1;
my $argB = 1;
my $argC = 0;
my $argT = 0;
my $file = "";

use constant {
    "True"  => 0,
    "False" => -1,
};

sub HelpMessage {
    print("
        Help TODO
        usage perl projekt2.pl [ --file | -f ] filename+params
    ");
    exit(0);
}

GetOptions(
    "file=s" => \$file,
    "help|?" => sub {HelpMessage()}
) or die("Error in command line arguments\n");

open my $open_file, $file or die "Could not open $file: $!";

my @params = ();
my @nodeTypes = ();         #NT
my @linkTypes = ();         #LTRA
my @nodes = ();             #N
my @links = ();             #L
my @initialActivation = (); #IA
my @linkWeights = ();       #LW

while (<$open_file>) {
    chomp;
    s/#.*//;                            # Remove comments
    my @inputData = split(" ", uc($_)); # Text split by whitespace to words
    my $size = @inputData;
    if ($size != 0) {
        if ($inputData[0] eq "NT") {
            push(@nodeTypes, \@inputData);
        }
        elsif ($inputData[0] eq "LTRA") {
            push(@linkTypes, \@inputData);
        }
        elsif ($inputData[0] eq "N") {
            push(@nodes, \@inputData);
        }
        elsif ($inputData[0] eq "L") {
            push(@links, \@inputData);
        }
        elsif ($inputData[0] eq "IA") {
            push(@initialActivation, \@inputData);
        }
        elsif ($inputData[0] eq "LW") {
            push(@linkWeights, \@inputData);
        }
        else {
            push(@params, \@inputData);
        }
    }

}
close $open_file;

# init params
foreach my $param (@params) {
    if (@$param[0] eq "BETA") {
        $argBeta = @$param[1];
    }
    elsif (@$param[0] eq "ITERATIONSNO") {
        $argIteration = @$param[1];
    }
    elsif (@$param[0] eq "CALIBRATION") {
        $argCalibration = @$param[1];
    }
    elsif (@$param[0] eq "A") {
        $argA = @$param[1];
    }
    elsif (@$param[0] eq "B") {
        $argB = @$param[1];
    }
    elsif (@$param[0] eq "C") {
        $argC = @$param[1];
    }
    elsif (@$param[0] eq "T") {
        $argT = @$param[1];
    }
}

# init nodes types
my %nodesTypes;
foreach my $nodeType (@nodeTypes) {
    $nodesTypes{ @$nodeType[1] } = 0;
}

# init link types
my %linkTypes;
foreach my $linkType (@linkTypes) {
    $linkTypes{ @$linkType[1] } = @$linkType[2];
}

# init link weights
my %linkWeights;
foreach my $links (@linkWeights) {
    foreach my $link ($links) {
        $linkWeights{ @$link[1] } = @$link[2];
    }
}

# init nodes
my %nodes;
foreach my $node (@nodes) {
    $nodes{ @$node[1] } = 0;
}

# init links
my %links;
foreach my $link (@links) {
    $links{ @$link[1] }{ @$link[2] } = {
        -weight           => $linkWeights{ @$link[3] },
        -passValue        => 0,
        -linkType         => @$link[3]
    };
}

# init active nodes
my %activeNodes;
foreach my $activeNode (@initialActivation) {
    $activeNodes{ @$activeNode[1] } = {
        -inputLinks      => {},
        -outputLinks     => {},
        -activeLevel     => @$activeNode[2],
        -newLevel        => 0,
        -valueSendToEdge => 0,
    };
}

# create reciprocal links
foreach my $link (keys(%links)) {
    foreach my $linkTest (keys(%{$links{$link}})) {
        if (not exists $links{$linkTest}{$link}) {
            $links{$linkTest}{$link} = {
                -weight           => $linkWeights{$linkTypes{ $links{$link}{$linkTest}{-linkType} }},
                -passValue        => 0,
            };
        }
    }
}

foreach my $nodeID (keys(%nodes)) {
    if (not exists $activeNodes{$nodeID}) {
        $activeNodes{$nodeID} = {
            -inputLinks      => {},
            -outputLinks     => {},
            -activeLevel     => 0,
            -newLevel        => 0,
            -valueSendToEdge => 0,
        };
    }
}

# found all input links
foreach my $activeNode (keys(%activeNodes)) {
    foreach my $link (keys(%links)) {
        if ($activeNode eq $link) {
            foreach my $l (keys(%{$links{$link}})) {
                $activeNodes{$activeNode}{-inputLinks}{$link} =
                    \$links{$link}{$l};
            }
        }
    }
}

# found all output links
foreach my $activeNode (keys(%activeNodes)) {
    foreach my $link (keys(%links)) {
        foreach my $linkTest (keys(%{$links{$link}})) {
            if ($activeNode eq $linkTest) {
                $activeNodes{$activeNode}{-outputLinks}{$link} =
                    \$links{$link}{$linkTest};
            }
        }

    }
}

# first iteration
my @outputDocs = ();
my $currIteration = 1;
my @outputDoc = ();
push @outputDoc, 0;
foreach my $node (sort keys %activeNodes) {
    if (exists $activeNodes{$node}{-activeLevel}) {
        push(@outputDoc, sprintf("%.5f", $activeNodes{$node}{-activeLevel}));
    }
    else {
        push(@outputDoc, 0);
    }
}
push(@outputDocs, [ @outputDoc ]);

# main loop
while ($currIteration <= $argIteration) {
    # count output value to edge
    foreach my $actNode (keys(%activeNodes)) {
        if ($activeNodes{$actNode}->{-activeLevel} gt 0) {
            my $valueSendToEdge = 0;
            if (scalar(keys(%{$activeNodes{$actNode}->{-outputLinks}})) == 0) {
                $activeNodes{$actNode}->{-valueSendToEdge} = $valueSendToEdge;
            }
            else {
                my $activeLevel = $activeNodes{$actNode}->{-activeLevel};
                my $outdegree = scalar(keys(%{$activeNodes{$actNode}->{-outputLinks}}));
                $valueSendToEdge = $activeLevel / $outdegree ** $argBeta;
                $activeNodes{$actNode}->{-valueSendToEdge} = $valueSendToEdge;
            }

            # set passValue to output links
            foreach my $outputLinks (keys(%{$activeNodes{$actNode}->{-outputLinks}})) {
                my $passValue = $activeNodes{$actNode}->{-valueSendToEdge} *
                    ${$activeNodes{$actNode}{-outputLinks}{$outputLinks}}->{-weight};
                ${$activeNodes{$actNode}{-outputLinks}{$outputLinks}}->{-passValue} = $passValue;

            }
        }
    }

    # new nodes value
    foreach my $actNode (keys(%activeNodes)) {
        if ($activeNodes{$actNode}->{-activeLevel} gt 0) {
            my $activeLevel = $activeNodes{$actNode}->{-activeLevel};
            my $output = 0;
            $output += ${$activeNodes{$actNode}{-outputLinks}{$_}}->{-passValue} foreach (keys(%{$activeNodes{$actNode}->{-outputLinks}}));
            my $newLevel = ($argA * $activeLevel) + ($argC * ($output));
            $activeNodes{$actNode}->{-newLevel} = $newLevel;
        }
    }

    # set output links new level value
    foreach my $actNode (keys(%activeNodes)) {
        foreach my $outputLinks (keys(%{$activeNodes{$actNode}->{-outputLinks}})) {
            my $newLevel = ${$activeNodes{$actNode}{-outputLinks}{$outputLinks}}->{-passValue};
            $newLevel += $activeNodes{$outputLinks}->{-newLevel};
            $activeNodes{$outputLinks}->{-newLevel} = $newLevel;
        }
    }

    # reduction and set newLevel -> activeLevel
    foreach my $actNode (keys(%activeNodes)) {
        my $newActLevel = $activeNodes{$actNode}->{-newLevel};
        if ($newActLevel lt $argT) {
            delete $activeNodes{$actNode};
        }
        else {
            $activeNodes{$actNode}->{-newLevel} = scalar(0);
            $activeNodes{$actNode}->{-activeLevel} = $newActLevel;
        }
    }

    @outputDoc = ();
    push(@outputDoc, $currIteration);

    foreach my $node (sort keys(%nodes)) {
        if (exists $activeNodes{$node}) {
            push(@outputDoc, sprintf("%.5f", $activeNodes{$node}->{-activeLevel}));
        }
        else {
            push(@outputDoc, sprintf("%.5f", 0));
        }
    }

    push(@outputDocs, [ @outputDoc ]);
    $currIteration++;
}

my @printHeader = ();
push(@printHeader, "iter.");
foreach my $node (sort keys(%nodes)) {
    push(@printHeader, $node);
}

my $table = Text::Table->new(@printHeader);
$table->load(@outputDocs);
print($table);
