#!/usr/bin/env perl
#
# viterbi.pl
#
# Description
#
# Use Viterbi algorithm to determine state.
#
use strict;

use Data::Dumper;
use Getopt::Long;
use JSON;
use List::Util qw(reduce);

my $debug;
my $markov_model_file;
my $observations_file;

GetOptions(
	"debug" => \$debug
	, "markov-model=s" => \$markov_model_file
	, "observations-file=s" => \$observations_file
	);

die "markov_model and observations_file\n"
	if (!($markov_model_file and $observations_file));



##############################################################################
#
# Import Markov Model
#
##############################################################################

sub viterbi
{
	my %p = @_;
	my $observations = $p{'observations'};
	my $training_data = $p{'training_data'};

	my $viterbi = [];
	my $path = {};
	my $index = 0;
	my $probability;
	my $state;
	my $new_path;

	# initialize base cases
	for my $state (@{$training_data->{'states'}}) {
		if ($debug) {
			printf "%6s: V[%-11g] -> T[%6s]P[%-4.2g] O[%s]P[%-8g] TP[%-11g]\n"
				, "start"
				, 1
				, $state
				, $training_data->{'start'}{'transition'}{$state} . "]\n"
				, $observations->[0]
				, $training_data->{$state}{'emission'}{$observations->[0]}
				, $training_data->{'start'}{'transition'}{$state}
					* $training_data->{$state}{'emission'}{$observations->[0]}
				;
		}

		my $start_state_probability
			= $training_data->{'start'}{'transition'}{$state}
			;

		my $emission_state_probability
			= $training_data->{$state}{'emission'}{$observations->[0]}
			;

		my $probability 
			= $start_state_probability
			* $emission_state_probability
			;

		$viterbi->[0]{$state} = $probability;

		$path->{$state} = [$state];
	}

	if ($debug) {
		($probability, $state) =
			@{
				reduce { $a->[0] > $b->[0] ? $a : $b }
				map {[
					$viterbi->[$index]{$_}
					, $_
				]}
				@{$training_data->{'states'}}
			};
		print "[$probability][$state]\n" . to_json($path->{$state}, {pretty => 1}) . "\n\n";
	}

	for my $i (1 .. scalar @{$observations} - 1) {
		$new_path = {};
		for my $next_state (@{$training_data->{'states'}}) {
			($probability, $state) = @{
				reduce { $a->[0] > $b->[0] ? $a : $b } 
				map {
					printf "%6s: V[%-11g] -> T[%6s]P[%-4.2g] O[%s]P[%-8g] TP[%-11g]\n"
						, $_
						, $viterbi->[$i - 1]{$_}
						, $next_state
						, $training_data->{$_}{'transition'}{$next_state}
						, $observations->[$i]
						, $training_data->{$next_state}{'emission'}{$observations->[$i]}
						, $viterbi->[$i - 1]{$_}
							* $training_data->{$_}{'transition'}{$next_state}
							* $training_data->{$next_state}{'emission'}{$observations->[$i]}

						;
					[
						$viterbi->[$i - 1]{$_}
							* $training_data->{$_}{'transition'}{$next_state}
							* $training_data->{$next_state}{'emission'}{$observations->[$i]}
						, $_
					]
				}
				@{$training_data->{'states'}}
			};
			$viterbi->[$i]{$next_state} = $probability;
			@{$new_path->{$next_state}} = (@{$path->{$state}}, ($next_state));
		}

		$path = $new_path;
		$index = $i;

		print to_json $path, {pretty => 1};
		($probability, $state) =
			@{
				reduce { $a->[0] > $b->[0] ? $a : $b }
				map {[
					$viterbi->[$index]{$_}
					, $_
				]}
				@{$training_data->{'states'}}
			};
		print "[$probability][$state]\n"
			. to_json($path->{$state}, {pretty => 1})
			. "\n\n";
	}

	# $index = 0;

	($probability, $state) =
		@{
			reduce { $a->[0] > $b->[0] ? $a : $b }
			map {[
				$viterbi->[$index]{$_}
				, $_
			]}
			@{$training_data->{'states'}}
		};

	return {
		'probability' => $probability
		, 'path' => $path->{$state}
	};
}



##############################################################################
#
# Import Markov Model
#
##############################################################################

sub import_markov_model {
	my $filename = shift;
	my $markov_model;
	my $markov_model_probabilities;

	open(FH, "<", $filename) or die "< $filename: cannot open $!";

	local $/;
	my $input = <FH>;

	$markov_model = from_json($input);

	# train system

	for my $state (keys %{$markov_model}) {
		$markov_model_probabilities->{$state} = ();
		if ($state eq 'states') {
			for my $new_state (@{$markov_model->{$state}}) {
				push @{$markov_model_probabilities->{$state}}, $new_state;
			}
		}
		else {
			for my $new_state (keys %{$markov_model->{$state}}) {
				my $total = reduce { $a + $b } values $markov_model->{$state}{$new_state};
				for my $value (keys %{$markov_model->{$state}{$new_state}}) {
					my $probability = $markov_model->{$state}{$new_state}{$value} / $total;
					$markov_model_probabilities->{$state}{$new_state}{$value} = $probability;
				}
			}
		}
	}

	return $markov_model_probabilities;
}



##############################################################################
#
# Import Observation Data
#
##############################################################################

sub import_observations_data {
	my $filename = shift;
	my $observations_data;

	open(FH, "<", $filename) or die "< $filename: cannot open $!";

	local $/;
	my $input = <FH>;

	$observations_data = from_json($input);

	return $observations_data;
}

my $observation_data = import_observations_data($observations_file);
my $training_data = import_markov_model($markov_model_file);

print to_json viterbi(
	  'training_data' => $training_data
	, 'observations' => $observation_data
	)
	, { pretty => 1 }
	;