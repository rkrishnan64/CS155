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
# main
#
##############################################################################
my $state = $markov_chain->{$markov_chain->{'start'}};
print next_state($state);

