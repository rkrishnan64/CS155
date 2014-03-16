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

my $all;
my $markov_model_file;
my $state_table_file;
GetOptions(
	"all" => \$all
	, "markov-model=s" => \$markov_model_file
	, "state-table=s" => \$state_table_file
	);


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
	return _get_value($state->{'transistion'});
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
		push @{$result}, {
			'state' => $state
			, 'emission' => get_emission($markov_model->{$state})
		};
		$state = get_transition($markov_model->{$state});
	}

	return $result;
}


##############################################################################
#
# main
#
##############################################################################

die "markov_model xor state_table"
	if (!($markov_model_file xor $state_table_file));

# print "MM [$markov_model_file]\n";

my $markov_model;
my $states;

if ($markov_model_file) {
	$markov_model = import_markov_model($markov_model_file);
	$states =  generate_states(
		'markov_model' => $markov_model
		, 'count' => 100
		);
}
if ($state_table_file) {
	$states = import_state_table($state_table_file);
}

# print Dumper $states;

my $output;

if ($all) {
	print to_json $states;
}
else {
	@{$output} = map { $_->{'emission'} } @{$states};
	# print Dumper $output;
	print to_json($output);
}
