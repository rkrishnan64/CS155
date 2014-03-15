#!/usr/bin/env perl
#
# generator.pl
#
# Description
#
# Generate a sequence of states from a Markov model.
#

use Data::Dumper;
use JSON;



##############################################################################
#
# Import Markov Model
#
##############################################################################

sub import_markov_model {
	my $filename = shift;
	my $markov_model = {};

	open(FH, "<", $filename) or die "< $filename: cannot open $!";

	local $/;
	my $input = <FH>;

	$markov_model = from_json($input);

	return $markov_model;
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

my $markov_model = import_markov_model('markov_model.data');
my $states =  generate_states(
	'markov_model' => $markov_model
	, 'count' => 100
	);

print Dumper $states;
