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
	'start' => {
		'transistion' => {
			s1 => 1
		}
		, 'emission' => {
			'start' => 1
		}
	}
	, 's1' => {
		'transistion' => {
			s1 => 1
			, s2 => 1
		}
		, 'emission' => {
			'head' => 5
			, 'tail' => 5
		}
	}
	, 's2' => {
		'transistion' => {
			s1 => 1
			, s2 => 2
		}
		, 'emission' => {
			'head' => 5
			, 'tail' => 5
		}
	}
};



##############################################################################
#
# Generate next state from current state.
#
##############################################################################

sub get_transition {
	$state = shift;
	return _get_value($state->{'transistion'});
}



##############################################################################
#
# Generate next state from current state.
#
##############################################################################

sub get_emission {
	$state = shift;
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
	my $markov_chain = $p{'markov_chain'};
	my $state = $p{'state'} ||= get_transition($markov_chain->{'start'});
	my $count = $p{'count'};
	my $result = [];

	foreach (1 .. $count) {
		push @{$result}, {
			'state' => $state
			, 'emission' => get_emission($markov_chain->{$state})
		};
		$state = get_transition($markov_chain->{$state});
	}

	return $result;
}


##############################################################################
#
# main
#
##############################################################################

#my $state = $markov_chain->{$markov_chain->{'start'}};
#print get_transition($state);

$states =  generate_states(
	'markov_chain' => $markov_chain
	, 'count' => 50
	);

print Dumper $states;
