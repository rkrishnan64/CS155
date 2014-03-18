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
my $emissions_file;

GetOptions(
	"debug" => \$debug
	, "markov-model=s" => \$markov_model_file
	, "emissions-file=s" => \$emissions_file
	);

die "markov_model and emissions_file\n"
	if (!($markov_model_file and $emissions_file));



##############################################################################
#
# Import Markov Model
#
##############################################################################

sub viterbi
{
	my %p = @_;
	my $observations = $p{'observations'};
	my $markov_model = $p{'markov_model'};

	my $viterbi = [];
	my $path = {};
	my $index = 0;
	my $probability;
	my $state;
	my $new_path;

	# initialize base cases
	for my $state (@{$markov_model->{'states'}}) {
		if ($debug) {
			printf "%6s: V[%-11g] -> T[%6s]P[%-4.2g] O[%s]P[%-8g] TP[%-11g]\n"
				, "start"
				, 1
				, $state
				, $markov_model->{'start'}{'transition'}{$state} . "]\n"
				, $observations->[0]
				, $markov_model->{$state}{'emission'}{$observations->[0]}
				, $markov_model->{'start'}{'transition'}{$state}
					* $markov_model->{$state}{'emission'}{$observations->[0]}
				;
		}

		my $start_state_probability
			= $markov_model->{'start'}{'transition'}{$state}
			;

		my $emission_state_probability
			= $markov_model->{$state}{'emission'}{$observations->[0]}
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
				@{$markov_model->{'states'}}
			};
		print "[$probability][$state]\n" . to_json($path->{$state}, {pretty => 1}) . "\n\n";
	}

	for my $i (1 .. scalar @{$observations} - 1) {
		$new_path = {};
		for my $next_state (@{$markov_model->{'states'}}) {
			($probability, $state) = @{
				reduce { $a->[0] > $b->[0] ? $a : $b } 
				map {
					printf "%6s: V[%-11g] -> T[%6s]P[%-4.2g] O[%s]P[%-8g] TP[%-11g]\n"
						, $_
						, $viterbi->[$i - 1]{$_}
						, $next_state
						, $markov_model->{$_}{'transition'}{$next_state}
						, $observations->[$i]
						, $markov_model->{$next_state}{'emission'}{$observations->[$i]}
						, $viterbi->[$i - 1]{$_}
							* $markov_model->{$_}{'transition'}{$next_state}
							* $markov_model->{$next_state}{'emission'}{$observations->[$i]}

						;
					[
						$viterbi->[$i - 1]{$_}
							* $markov_model->{$_}{'transition'}{$next_state}
							* $markov_model->{$next_state}{'emission'}{$observations->[$i]}
						, $_
					]
				}
				@{$markov_model->{'states'}}
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
				@{$markov_model->{'states'}}
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
			@{$markov_model->{'states'}}
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
# Import Emissions Data
#
##############################################################################

sub import_emissions_data {
	my $filename = shift;
	my $emissions_data;

	open(FH, "<", $filename) or die "< $filename: cannot open $!";

	local $/;
	my $input = <FH>;

	$emissions_data = from_json($input);

	return $emissions_data;
}


print to_json viterbi(
	  'markov_model' => import_markov_model($markov_model_file) 
	, 'observations' => import_emissions_data($emissions_file)
	)
	, { pretty => 1 }
	;