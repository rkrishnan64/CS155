#!/usr/bin/env perl
#
# generator.pl
#
# Description
#
# Generate a sequence of states from a Markov model.
#

use Data::Dumper;
use Getopt::Long;
use JSON;

my $help;
my $verbose;
my $markov_model_file;
my $state_table_file;
my $count;
my $default_count = 3;

GetOptions(
	"help|h" => \$help
	, "verbose" => \$verbose
	, "markov-model=s" => \$markov_model_file
	, "state-table=s" => \$state_table_file
	, "count=i" => \$count
	);

my $SYNOPSIS = <<EOF;
$0 --markov-model xor --state-table FILE [--verbose] [-h]
EOF

my $HELP = <<EOF;
$SYNOPSIS
    Generate emissions for given markov model.


    One of either but not both of --markov-model or --state-table must be specified.

    --markov-model[=| ]FILE
        Markov model data filename.

    --state-table[=| ]FILE
        State table data filename.

    --count[=| ]count
        Number of states to output.

    --verbose
        Output all state data. Default outputs emissions only.

    --help, -h
        Print a help message and exit.

EOF

die $HELP if $help;

die $SYNOPSIS
	if (!($markov_model_file xor $state_table_file));


##############################################################################
# main
##############################################################################

# print "MM [$markov_model_file]\n";

my $markov_model;
my $states;

if ($markov_model_file) {
	$markov_model = import_markov_model($markov_model_file);
	$count ||= $default_count;
	$states =  generate_states(
		'markov_model' => $markov_model
		, 'count' => $count
		);
}

if ($state_table_file) {
	$states = import_state_table($state_table_file);
	$count ||= scalar @{$states};
	$count = $count < scalar @{$states} ? $count : scalar @{$states};
	$states = [@{$states}[0 .. $count - 1]];
}

# print Dumper $states;

my $output;

if ($verbose) {
	print to_json $states, { pretty => 1 };
}
else {
	@{$output} = map { $_->{'emission'} } @{$states};
	print to_json $output, { pretty => 1 };
}



##############################################################################
#
# Import Markov Model
#
##############################################################################

sub import_markov_model {
	my $filename = shift;
	my $markov_model;

	open(FH, "<", $filename) or die "< $filename: cannot open $!";

	local $/;
	my $input = <FH>;

	$markov_model = from_json($input);

	return $markov_model;
}



##############################################################################
#
# Import State Table
#
##############################################################################

sub import_state_table {
	my $filename = shift;
	my $state_table;

	open(FH, "<", $filename) or die "< $filename: cannot open $!";

	local $/;
	my $input = <FH>;

	$state_table = from_json($input);

	return $state_table;
}



##############################################################################
#
# Generate next state from current state.
#
##############################################################################

sub get_transition {
	my $state = shift;
	return _get_value($state->{'transition'});
}



##############################################################################
#
# Generate next state from current state.
#
##############################################################################

sub get_emission {
	my $state = shift;
	return _get_value($state->{'emission'});
}



##############################################################################
#
# Generate next state from current state.
#
##############################################################################

sub _get_value
{
	my $state = shift;

	my $state_index = 0;
	my $state_table = {};

	my $next_state;

	foreach (keys %{$state}) {
		$state_index += $state->{$_};
		$state_table->{$state_index} = $_;
	}

	my $random = int(rand($state_index));
	for my $index (sort { $a <=> $b} keys %{$state_table}) {
		if ($random < $index) {
			$next_state = $index;
			last;
		}
	}

	return $state_table->{$next_state};
}



##############################################################################
#
# Generate states
#
##############################################################################

sub generate_states
{
	my %p = @_;
	my $markov_model = $p{'markov_model'};
	my $state = $p{'state'} ||= get_transition($markov_model->{'start'});
	my $count = $p{'count'};
	my $result = [];

	foreach (1 .. $count) {
		$state = get_transition($markov_model->{$state});
		push @{$result}, {
			'state' => $state
			, 'emission' => get_emission($markov_model->{$state})
		};
	}

	return $result;
}
