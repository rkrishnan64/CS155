#!/usr/bin/env perl
#
# generator.pl
#
# Description
#
# Generate a sequence of states from a Markov model.
#

use Data::Dumper;

##############################################################################
#
# markov chain
#
##############################################################################

my $markov_chain = {
	'start' => 'head'
	, 'head' =>
		{
			'head' => 5
			, 'tail' => 5
		}
	, 'tail' =>
		{
			'head' => 5
			, 'tail' => 5
		}
};



##############################################################################
#
# Generate next state from current state.
#
##############################################################################

sub next_state
{
	my $state = shift;

	my $state_index = 0;
	my $state_table = {};

	my $next_state_index;

	foreach (keys %{$state}) {
		$state_index += $state->{$_};
		$state_table->{$state_index} = $_;
	}

	my $random = int(rand($state_index));
	for my $index (sort { $a <=> $b} keys %{$state_table}) {
		if ($random < $index) {
			$next_state_index = $index;
			last;
		}
	}

	return $state_table->{$next_state_index};
}



##############################################################################
#
# Generate states
#
##############################################################################

sub generate_states
{
	my %p = @_;
	my $markov_chain = $p{'markov_chain'};
	my $state = $p{'state'} ||= $markov_chain->{'start'};
	my $count = $p{'count'};
	my $result = [];

	foreach (1 .. $count) {
		push @{$result}, $state;
		$state = next_state($markov_chain->{$state});
	}

	return $result;
}


##############################################################################
#
# main
#
##############################################################################

#my $state = $markov_chain->{$markov_chain->{'start'}};
#print next_state($state);

$states =  generate_states(
	'markov_chain' => $markov_chain
	, 'count' => 50
	);

print Dumper $states;
