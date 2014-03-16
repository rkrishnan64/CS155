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

my $markov_model_file;
my $emissions_file;

GetOptions(
	"markov-model=s" => \$markov_model_file
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

	# print to_json $observations, { pretty => 1 };
	# print to_json $markov_model, { pretty => 1 };

	my $viterbi = [];
	my $path = {};
	my $state;

	# initialize base cases
	# my $total_transition_weights = reduce { $a + $b } values $markov_model->{'start'}{'transition'};
	# my $total_emission_weights;
	# print "Max transition weights [$total_transition_weights]\n";
	for my $state (@{$markov_model->{'states'}}) {
		# $total_emission_weights = reduce { $a + $b } values $markov_model->{$state}{'emission'};

		print "start transition [" . $markov_model->{'start'}{'transition'}{$state} . "]\n";

		my $previous_state_probability
			= $markov_model->{'start'}{'transition'}{$state}
			# / $total_transition_weights
			;

		print "[$state][" . $observations->[0] 
			. "][" . $markov_model->{$state}{'emission'}{$observations->[0]} 
			# . "][" . $total_emission_weights
			. "]\n";

		my $current_state_probability
			= $markov_model->{$state}{'emission'}{$observations->[0]}
			# / $total_emission_weights
			;

		print "[$previous_state_probability] [$current_state_probability]\n";
		$viterbi->[0]{$state}
			= $previous_state_probability
			* $current_state_probability
			;

		$path->{$state} = [$state];
	}

	print to_json $viterbi, { pretty => 1 };
	print to_json $path, { pretty => 1 };

	my $index = 0;
	my $new_path;
	my $probability;
	my $path_state;

	for my $i (1 .. scalar @{$observations} - 1) {
		# print "index [$i]\n";
		$new_path = {};

		for my $state (@{$markov_model->{'states'}}) {
			($probability, $path_state) = @{
				reduce { $a->[0] > $b->[0] ? $a : $b } 
				map {
					printf "%8s: V[%g] T[%g] E[%g] P[%g]\n"
						, $_
						, $viterbi->[$i - 1]{$_}
						, $markov_model->{$_}{'transition'}{$state}
						, $markov_model->{$state}{'emission'}{$observations->[$i]}
						, $viterbi->[$i - 1]{$_}
						* $markov_model->{$_}{'transition'}{$state}
						* $markov_model->{$state}{'emission'}{$observations->[$i]}

						;
					[
						$viterbi->[$i - 1]{$_}
						* $markov_model->{$_}{'transition'}{$state}
						* $markov_model->{$state}{'emission'}{$observations->[$i]}
						, $_
					]
				}
				@{$markov_model->{'states'}}
			};
			print "[$probability][$path_state]\n";
			$viterbi->[$i]{$state} = $probability;
			push @{$path->{$state}}, $path_state;
			print "\n";
		}
		print "\n";
		$index = $i;
	}

	# $index = 0;

	($probability, $path_state) =
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
		, 'path' => $path->{$path_state}
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