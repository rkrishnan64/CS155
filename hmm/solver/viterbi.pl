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

my $help;
my $debug;
my $markov_model_file;
my $observations_file;

GetOptions(
	"help|h" => \$help
	, "debug" => \$debug
	, "markov-model=s" => \$markov_model_file
	, "observations=s" => \$observations_file
	);

my $SYNOPSIS = <<EOF;
$0 --markov-model[=| ]FILE --observations[=| ]FILE [-h]
EOF

my $HELP = <<EOF;
$SYNOPSIS
    Viterbi prediction for the markov model and observations.

    --markov-model[=| ]FILE
        Markov model data filename.

    --observations[=| ]FILE
        Oservations data filename.

    --help, -h
        Print a help message and exit.

EOF

die $HELP if $help;

die $SYNOPSIS
	if (!($markov_model_file and $observations_file));



##############################################################################
# Main
##############################################################################

my $markov_model = import_markov_model($markov_model_file);
my $training_data = get_training_data($markov_model);
my $observation_data = import_observations_data($observations_file);

print to_json viterbi(
	  'training_data' => $training_data
	, 'observations'  => $observation_data
	)
	, { pretty => 1 }
	;



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
					+ $training_data->{$state}{'emission'}{$observations->[0]}
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
				reduce {
					$a->[0] > $b->[0] ? $a : $b
				}
				map {
					[$viterbi->[$index]{$_}, $_]
				}
				@{$training_data->{'states'}}
			};
		print "[$probability][$state]\n" . to_json($path->{$state}, {pretty => 1}) . "\n\n";
	}

	for my $i (1 .. scalar @{$observations} - 1) {
		$new_path = {};
		for my $next_state (@{$training_data->{'states'}}) {
			($probability, $state) = @{
				reduce {
					$a->[0] > $b->[0] ? $a : $b
				} 
				map {
					if ($debug) {
						printf "%6s: V[%-11g] -> T[%6s]P[%-6.2g] O[%s]P[%-8g] TP[%-11g]\n"
							, $_
							, $viterbi->[$i - 1]{$_}
							, $next_state
							, $training_data->{$_}{'transition'}{$next_state}
							, $observations->[$i]
							, $training_data->{$next_state}{'emission'}{$observations->[$i]}
							, $viterbi->[$i - 1]{$_}
								+ $training_data->{$_}{'transition'}{$next_state}
								+ $training_data->{$next_state}{'emission'}{$observations->[$i]}
							;
					}
					[
						$viterbi->[$i - 1]{$_}
							+ $training_data->{$_}{'transition'}{$next_state}
							+ $training_data->{$next_state}{'emission'}{$observations->[$i]}
						, $_
					]
				}
				@{$training_data->{'states'}}
			};
			$viterbi->[$i]{$next_state} = $probability;
			$new_path->{$next_state} = [@{$path->{$state}}, ($next_state)];
		}

		$path = $new_path;
		$index = $i;

		if ($debug) {
			($probability, $state) =
				@{
					reduce {
						$a->[0] > $b->[0] ? $a : $b
					}
					map {
						[$viterbi->[$index]{$_}, $_]
					}
					@{$training_data->{'states'}}
				};
			print to_json $path, {pretty => 1};
			print "[$probability][$state]\n"
				. to_json($path->{$state}, {pretty => 1})
				. "\n\n";
		}
	}

	# $index = 0;

	($probability, $state) =
		@{
			reduce {
				$a->[0] > $b->[0] ? $a : $b
			}
			map {
				[$viterbi->[$index]{$_}, $_]
			}
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
	my $training_data;

	open(FH, "<", $filename) or die "< $filename: cannot open $!";

	local $/;
	my $input = <FH>;

	$markov_model = from_json($input);

	return $markov_model;
}



##############################################################################
#
# get_training_data
#
##############################################################################

sub get_training_data
{
	my $markov_model = shift;
	my $training_data = {};

	for my $state (keys %{$markov_model}) {
		$training_data->{$state} = ();
		if ($state eq 'states') {
			for my $new_state (@{$markov_model->{$state}}) {
				push @{$training_data->{$state}}, $new_state;
			}
		}
		else {
			for my $new_state (keys %{$markov_model->{$state}}) {
				my $total = reduce { $a + $b } values $markov_model->{$state}{$new_state};
				for my $value (keys %{$markov_model->{$state}{$new_state}}) {
					my $probability = (log $markov_model->{$state}{$new_state}{$value})
						- (log $total);
					$training_data->{$state}{$new_state}{$value} = $probability;
				}
			}
		}
	}

	return $training_data;
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
